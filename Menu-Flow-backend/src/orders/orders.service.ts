import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Customer, DeliveryZone, Order, Product } from '../common/schemas';
import { OrdersGateway } from './orders.gateway';

export type CheckoutItem = { productId: string; quantity: number; addonNames?: string[]; observation?: string };
export type CheckoutInput = {
  customerName: string; phone: string; fulfillment: 'DELIVERY' | 'PICKUP'; paymentMethod: string;
  address?: Record<string, string>; changeFor?: number; couponCode?: string; items: CheckoutItem[];
};

@Injectable()
export class OrdersService {
  constructor(
    @InjectModel(Order.name) private readonly orders: Model<Order>,
    @InjectModel(Product.name) private readonly products: Model<Product>,
    @InjectModel(Customer.name) private readonly customers: Model<Customer>,
    @InjectModel(DeliveryZone.name) private readonly zones: Model<DeliveryZone>,
    private readonly gateway: OrdersGateway,
  ) {}

  async create(restaurantId: string, input: CheckoutInput) {
    if (!Types.ObjectId.isValid(restaurantId)) throw new NotFoundException('Restaurant not found');
    if (input.fulfillment === 'DELIVERY' && !input.address?.neighborhood) {
      throw new BadRequestException('Neighborhood is required for delivery');
    }
    const productIds = input.items.map(({ productId }) => productId);
    if (productIds.some((id) => !Types.ObjectId.isValid(id))) throw new BadRequestException('Invalid product');
    const products = await this.products.find({ _id: { $in: productIds }, restaurantId, available: true }).lean();
    if (products.length !== new Set(productIds).size) throw new BadRequestException('One or more products are unavailable');
    const productById = new Map(products.map((product) => [product._id.toString(), product]));
    const items = input.items.map((item) => {
      const product = productById.get(item.productId);
      if (!product || item.quantity < 1) throw new BadRequestException('Invalid order item');
      const allowed = new Map(product.addonGroups.flatMap((group) => group.addons.map((addon) => [addon.name, addon.price])));
      const addons = (item.addonNames ?? []).map((name) => {
        const price = allowed.get(name);
        if (price === undefined) throw new BadRequestException(`Invalid add-on: ${name}`);
        return { name, price };
      });
      return { productName: product.name, unitPrice: product.promotionalPrice ?? product.price, quantity: item.quantity, addons, observation: item.observation };
    });
    const subtotal = items.reduce((sum, item) => sum + item.quantity * (item.unitPrice + item.addons.reduce((total, addon) => total + addon.price, 0)), 0);
    let deliveryFee = 0;
    if (input.fulfillment === 'DELIVERY') {
      const zone = await this.zones.findOne({ restaurantId, name: input.address?.neighborhood, active: true }).lean();
      if (!zone) throw new BadRequestException('Delivery is unavailable for this neighborhood');
      deliveryFee = zone.fee;
    }
    const order = await this.orders.create({ ...input, restaurantId: new Types.ObjectId(restaurantId), items, subtotal, deliveryFee, discount: 0, total: subtotal + deliveryFee });
    await this.customers.findOneAndUpdate(
      { restaurantId, phone: input.phone },
      { $set: { name: input.customerName, lastOrderAt: new Date() }, $addToSet: input.address ? { addresses: input.address } : {}, $inc: { orderCount: 1, totalSpent: order.total } },
      { upsert: true, new: true },
    );
    this.gateway.publishNewOrder(restaurantId, order.toJSON());
    return order;
  }

  list(restaurantId: string) { return this.orders.find({ restaurantId }).sort({ createdAt: -1 }).lean(); }
}
