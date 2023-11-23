/*
 * This file provides a queue for storing packets that should be sent over a communication channel.
 * The System.AsyncIO module makes use of the queue defined here.
 *
 * The packets sent need to be stored because data is sent by System.AsyncIO
 * using the synchronous,non-blocking write operation.
 *
 * This queue implementation could be replaced by an generic queue implementation (external library).
 * As long as the queue were made to implement the enqueueFront function (queuing data in front).
 */

typedef struct packet_t packet_t;
typedef struct packet_t {
	char* data;
	int size;
	packet_t* next_packet;
} packet_t;

typedef struct queue_t {
	packet_t* begin;
	packet_t* end;
} queue_t;

queue_t* initQueue();
packet_t* createPacket(char* data, int size);
int enqueue(queue_t* queue, char* data, int size);
int enqueueFront(queue_t* queue, char* data, int size);
packet_t* dequeue (queue_t* queue);
int isEmpty (queue_t* queue);
int freeQueue (queue_t* queue);
