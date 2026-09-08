import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

/** Restaurant rooms prevent order events leaking across tenants. */
@WebSocketGateway({ cors: { origin: process.env.FRONTEND_URL?.split(',') ?? true } })
export class OrdersGateway {
  @WebSocketServer() server!: Server;

  publishNewOrder(restaurantId: string, order: unknown) {
    this.server.to(`restaurant:${restaurantId}`).emit('order.created', order);
  }
}
