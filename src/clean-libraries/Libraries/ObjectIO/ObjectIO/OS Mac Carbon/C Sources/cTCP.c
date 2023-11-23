/*
			Ctcp	-	functions for using Open Transport from Clean

			written by Martin Wierich
			
This file contains the following sections:
	THE REENTRANCY PROBLEM
	THE ENDPOINT DICTIONARY
	USED CONFIGURATIONS
	ABOUT THE MODE OF OPERATION
	MISCELLANEOUS
	TYPE DEFINITIONS
	THE FUNCTION PROTOTYPES
	GLOBAL VARIABLES
	FUNCTION IMPLEMENTATIONS
	FUNCTION IMPLEMENTATIONS FOR THE ENDPOINT DICTIONARY


------------ THE REENTRANCY PROBLEM -----------------------------------

Open Transport is a very stupid invention of Apple Inc. !!!!

The TCP Interface for Clean should of course provide an event driven part.
Open Transport does not generate real Mac events, instead Open Transport
calls a user defined "notifier function". For instance, when some data has arrived
via the network for a certain endpoint, then the endpoint's notifier function is
called with the T_DATA event code (and certain other parameters).
This happens at "deferred task time",
and it can happen REENTRANTLY. At deferred task time only a limited set of
functions are allowed to be called, e.g. no Toolbox function may be called.
Reentrancy means, that not only the normal control flow of a running application
may be interrupted by the notifier function, but the notifier function may interrupt
itself with another event. This makes implementing the event driven part for Clean's
TCP interface so complicated.

"Open Transport attempts ... to prevent reentrancy ... , but this behaviour is not
guaranteed. You should be prepared and write your notifier function defensively."
(Networking with Open Transport, Chapter 3 - Providers, Using Notifier Functions to
 Handle Provider Events)

The solution to get events to Clean is the following: Each time when a notifier function
is called with an event, that should be handled from Clean, this event is stored in
a FIFO list (in C). I call this list "inetEventQueue". Always when the Clean part calls the
"WaitNextEvent" function, it's checked, whether there is an event in this list
to be handled.

Without reentrancy this would be easy: Simply add a newly allocated item to the
inetEventQueue. Reentrancy introduces a problem, which the following scenario exemplifies:
	The notifier function is called with an event. This event has to be added to the
inetEventQueue. This is done with two pointer manipulations. If now another Open Transport
"event" happens, the notifier function
may be interrupted during these two pointer manipulations. This second call of the notifier
function will do the same pointer manipulations on the same global variables.
This has the consequence, that one event can be lost. This behaviour has to be prevented.

Preventing this would be easy, if Apple would offer some good mechanism to protect
critical sections. But there is only such a mechanism for one endpoint: The OTEnterNotifier
function gets as parameter an endpoint reference. After it's called, the endpoint's notifier
function will not be called. Unfortunately other endpoint's notifier functions can still be
called.

The solution is the following: Before the pointer manipulations happen, 
a flag "inCS" (in critical section) is set to true. The first thing, a notifier function
does, is to check this flag. If the flag is set, the event will NOT be added to the
inetEventQueue. Instead it will be stored in another queue, which is private to the endpoint.
(These queues are also implemented by this module). Using private queues for each endpoint
allows using the OTEnterNotifier function to protect this critical section.
So there are two kinds of critical sections: In the first kind the inetEventQueue is accessed.
It is protected by setting the inCS flag. In the second kind an event is added to an endpoint's
private event queue, and it's protected with the OTEnterNotifier function.
I call storing the event in an endpoint's private queue "deferring" the event.
When an event is deferred, another flag "deferredEventExists" is set. After completion of a
critical section of the first kind, the flag "inCS" has to be set to false, and eventually
deferred events have to be added to the global inetEventQueue. The following is a simplified
version of a possible notifier function, to show the principle:

void notifier(	OTEventCode eventCode, EndpointRef epRef, privateQueue)
{
	if (inCS)
		{	deferredEventExists	= true;
			addEventToPrivateQueue(privateQueue,eventCode);
		}
	  else
		{
			inCS	= true;		// begin critical section
			addEventToGlobalQueue(eventCode);
			inCS	= false; 	// end critical section
			
			while(deferredEventExists)
				{	inCS	= true;	// begin critical section
					deferredEventExists	= false;
						// this value might be set to true again, 
						// when this critical section is reentrantly interrupted
					add_all_deferred_events_into_global_queue();
					inCS	= false;// end critical section
				};
		};
}

---------------------  THE ENDPOINT DICTIONARY -------------------------------------

This module also implements a dictionary for the endpoints. In my definition, a dictionary
is a container data structure, where one can add a new item, look it up with a key,
and remove it. The key to look up the container elements is the endpoint reference.
An item is of type struct dictitem. The dictionary is implemented as a linked list, since a
lookup does not happen often. The global "endpointDict" points to the head of this list
>From Clean, the following fields are seen:

		void	*acceptInfo;			// !=0(nil), iff a connect request is pending (only for listening endpoints)
		int		referenceCount;			
		bool	hasReceiveNotifier;		// whether a receiver for a TCP_RChan is open
		bool	hasSendableNotifier;	// whether a receiver (send notifier) for a TCP_SChan is open
	
The acceptInfo field can only be read from Clean, all others can be read and written.
The acceptInfo field is used from Clean to poll, whether a connection request is pending.
The reference count is used because one endpoint is for two channels, a TCP_RChan and
a TCP_SChan. When a TCP_DuplexChan is created, this field will be set to two. Closing
one of the two channels will decrement the referenceCount. An item in the dictionary
will be garbage collected, when the reference count is zero, and when the endpoint state is
IDLE. The hasReceiveNotifier and hasSendableNotifier fields are used to decide, whether
an Open Transport event should be passed to Clean (added to the inetEventQueue). So non IO
programs will store no event in the queue !

Items have to be removed from within the notifier function, because of the T_UNBINDCOMPLETE
event. Because of reentrancy, this removal should not be done with pointer manipulation.
Instead, a "valid" field of the dictionary item is set to false, and a "invalid_dictitems_exist"
field is set to true. In this way, invalid dictionary entries can be removed later from outside
the notifier. This happens in function "getNextInetEvent". 

The endpoint's private event queue is also stored in it's dictionary entry. The following
fields implement this queue:

		event			*deferredEvents;
		event			**toLastNextDI;

deferredEvents points to the head of the queue, and toLastNextDI points to the "next"
field of the last list element (analogue to inetEventQueue and toLastNext)

The "context" parameter of the notifier function will always be a pointer to the endpoint's
dictionary entry !!!

------------------------- USED CONFIGURATIONS  ---------------------------------

For TCP_S(R)Chans kTCPName is used.
For TCP_Listeners "tilisten,tcp" is used. In this way there can be only one pending
connection request.
The lookupHost_syncC function returns a looked up IP Address. It uses a mapper endpoint, whose
endpoint reference is stored in the global "syncDNRMapper".
For asynchronous DNS queries via function lookupHost_async, mapper endpoints are created
for each request. Both kinds of endpoints for DNS queries have the configuration "kDNRName".

-------------------------  ABOUT THE MODE OF OPERATION  ---------------------------------

Open Transport defines two mode of operation parameters. One distincts  between 
synchronous/asynchronous, and the other one between blocking/non-blocking (see
"Networking with Open Transport"). Endpoints for TCP_S(R)Chans and TCP_Listeners
are in synchronous non-blocking mode. This mode is only temporarily
changed, because some Open Transport functions require asynchronous mode within
the notifier function (because of "deferred task time").
The "syncDNRMapper" is in synchronous blocking mode. 
The mode of operation for mapper endpoints for asynchronous DNS queries is of course
asynchronous non-blocking.

------------------------  MISCELLANEOUS  -------------------------------------------

kOTSyncIdleEvents are NOT used

------------------------ TYPE DEFINITIONS -----------------------------------------
*/

#define KARBON 1

#ifndef __MACH__
#include <Carbon.h>
//#include <OpenTransport.h>
//#include <OpenTptInternet.h>
//#include <events.h>
#else
#include <Carbon/Carbon.h>
#endif

#include "Clean.h"

//#ifdef __MACH__
#if defined __MACH__ || defined KARBON
# define InitOpenTransport() InitOpenTransportInContext(kInitOTForApplicationMask,NULL)
# define CloseOpenTransport() CloseOpenTransportInContext(NULL)
# define OTAlloc(ref,structType,fields,err) OTAllocInContext(ref,structType,fields,err,NULL)
# define OTAllocMem(size) OTAllocMemInContext(size,NULL)
# define OTOpenEndpoint(config,oflag,info,err) OTOpenEndpointInContext(config,oflag,info,err,NULL)
# define OTOpenMapper(config,oflag,err) OTOpenMapperInContext(config,oflag,err,NULL)
#endif

//	the items, which are stored in inetEventQueue
struct event
  {	int				endpointRef;
	int				eventCode;
	int				receiverCategory;
	int				misc;
	struct event	*next;	// a linked list
  };
typedef struct event event;

// the dictionary items
struct dictitem
	{	EndpointRef		endpointRef;
		void			*acceptInfo;
		struct dictitem	*next;
		int				valid;
		event			*deferredEvents;
		event			**toLastNextDI;
			// stores deferred events to handle reentrancy problems
		int				dnsEndpointRef;
			// stores a "fake" endpoinRef (for asynchronous DNS queries only)
		TCall			*connectTCallP;
			// points to TCall structure used for asynchronous connects
		TCall			*tcallSaveP;
			// possibly points to TCall structure, only for freeing the memory when
			// item is garbage collected or removed
		TLookupRequest	*lookupRequestP;
			// is used for deallocating the TLookupRequest structure in the notifier,
			// when an asynchronous DNS lookup has completed.
		char			availByte;
		unsigned		availByteValid		: 1;
		unsigned		referenceCount		: 2;
		unsigned		hasReceiveNotifier	: 1;
			// three kinds of receivers: receivers for established connections,
			// receivers for dns requests, receivers for asynchronous conect
		unsigned		hasSendableNotifier	: 1;
		unsigned		aborted			: 1;
		unsigned		channelFull			: 1;
	};
typedef struct dictitem dictitem;

/*
------------------------ THE FUNCTION PROTOTYPES ------------------------------------------

Naming convention: functions, which are called from Clean end with a "C". Function's that
acces or manipulate the inetEventQueue begin with "CS". They require the "inCS" flag to be
set.
The "CFN" in the comments means "called from notifier". These functions have to deal with 
reentrancy.
There are two special groups of functions: functions, which are called from Clean and
functions to deal with the endpoint dictionary.
*/

void WaitNextEventC(int eventMask,int sleep,int mouseRgn, int in_tb,
					int *interesting,int *what,int *message,int *when,int *h,int *v,int *mods,
					int *out_tb);
void gNextInetEvent(int *eventCode, int *endpointRef, int *receiverCategory, int *misc);
void poll(int nRChannels,EndpointRef *rChannels, dictitem **rDictitems, int *channelTypes,
		  int nSChannels,EndpointRef *sChannels, dictitem **sDictitems,
		  int *pSomething_happened);
int CS_found(int endpointRef, int eventCode, event *queueP);
void setupLookupParams(char *inetAddr,
					   TLookupRequest *request, TLookupReply *reply,
					   int *err);
OTResult event_pending(EndpointRef endpointRef);
int simple_receive(EndpointRef endpointRef, int maxSize, char* empty);
//************************************************
// functions, which are called from Clean (semantic is explained in tcp.icl or ostcp.icl)

void lookupHost_syncC(char* inetAddr, int *errCode, int *ipAddr);
void lookupHost_asyncC(char* inetAddr, int *errCode, int *endpointRef);
void openTCP_ListenerC(int portNum, int *errCode, int *endpointRef);
void acceptC(int endpointRef, int *errCode, int *inetHostP, int *newEpRefP);
void os_connectTCPC(int isIOProg, int block, int doTimeout, unsigned int stopTime, char *destination,
					int *errCode, int *timeoutExpiredP, int *endpointRefP);
void sendC(EndpointRef endpointRef, CleanString data, int begin, int nBytes,
			int *pErrCode, int *pSentBytes);
void receiveC(EndpointRef endpointRef, int maxSize, CleanString *data);
int data_availableC(EndpointRef endpointRef);
int os_connectrequestavailable(int endpointRef);
int getEndpointStateC(int endpointRef);
void disconnectGracefulC(int endpointRef);
void disconnectBrutalC(int endpointRef);
void ensureEventInQueueC(int endpointRef, int eventCode, int receiverCategory);
void garbageCollectEndpointC(int endpointRef);
void CleanUp();
void selectChC(int isIOProg, int justForPC, int doTimeout, unsigned int stopTime, 
			 EndpointRef *pRChannels, int *rcvTypes, EndpointRef *pSChannels,
			 int *pErrCode);
int tcpPossibleC();

//************************************************
// other functions

void StartUp();
	// start Open Transport (if not started yet. uses global "tcpStartedUp")
void StartUpSyncDNR();
	// initialize mapper endpoint for synchronous DNS queries
void getNextInetEvent(int *eventCode, int *endpointRef, int *receiverCategory, int *misc);
	// get the next event. If there is no event, eventCode is zero
pascal void notifier(	void* dictitemP, OTEventCode eventCode,
						OTResult result, void* cookie);
	// the one and only notifier function (for all endpoints)
pascal void generalHandler(	dictitem *dictitemP, void* epRef, OTEventCode eventCode);
	// CFN: reacts with the corresponding function calls to Open Transport events
void CS_evtlAddEventToQueue(dictitem* dictitemP, OTEventCode eventCode,
							OTResult result, void* cookie, event ***toLastNextP);
	// adds event to inetEventQueue, iff there is a receiver, which s waiting for such an event 
	// (CFN)
void CS_addEventToQueue(int endpointRef,int eventCode, int receiverCategory, int misc, event ***toLastNextP);
	// adds new struct event to inetEventQueue (CFN)
void handleDeferredEvents();
	// adds the possibly deferred events to the inetEventQueue, has to be called after each
	// critical section of first kind (see above)
void deferEvent(dictitem *dictitemP,OTEventCode eventCode,
				OTResult result, void* cookie);
	// store event into the endpoint's private event queue (CFN)
void CS_add_deferred_events_into_queue();
	// move all deferred events from all endpoints to the global inetEventQueue
void createChannelEndpoint(int *errCode, EndpointRef *ep_p);
	// create new endpoint for new TCP_S(R)Chan and do some initialisation actions
void gcEndpoint(int endpointRef);
	// garbage collect endpoint: iff referenceCount==0 and state of endpoint==IDLE, then
	// close the endpoint, and remove dictionary item. (CFN)
void handle_update_or_mouse_down_event (EventRecord *event_p);
	// defined in cgcon.c


void ew_print_string(char*);
void ew_print_int(int);
void IO_error(char *);
//************************************************
// functions to deal with the endpoint dictionary:

int insertNewDictionaryItem(EndpointRef endpointRef);
	// allocates memory for new dictionary item, initializes it as far as possible and
	// adds it to the dictionary. returns error code: 0==ok, 1==not ok
dictitem* lookup(EndpointRef endpointRef);
	// lookup entry (CFN)
void setEndpointDataC(	int endpointRef, int referenceCount,
						int hasReceiveNotifier, int hasSendableNotifier, int aborted);
	// set the corresponding fields of the entry 
void getEndpointDataC(	int endpointRef, int *referenceCount,
						int *hasReceiveNotifier, int *hasSendableNotifier, int *aborted);
	// returns the corresponding fields of the entry 
void removeDictionaryItem(EndpointRef endpointRef);
	// remove one item via pointer manipulations (must not be called from notifier)
void invalidateDictionaryItem(dictitem *dictitemP);
	// set "valid" field to false (item will be removed later) (CFN)
void remove_invalid_dictitems(dictitem **ptr);
	// remove those items, which have a false valid flag (must not be called from notifier)

//--------------------- GLOBAL VARIABLES ------------------------------------------

//	The inetEventQueue: To append easily a new item to the end of the list, "toLastNext" points
//	to the "next" field of the last list element (or to &inetEventQueue)

event		*inetEventQueue = nil;
event		**toLastNext = &inetEventQueue;
int			inCS = false,
			deferredEventExists	= false;

dictitem	*endpointDict = nil;
int	invalid_dictitems_exist  = false;

int			tcpStartedUp = false,
			syncDNRStartedUp = false;
MapperRef	syncDNRMapper;	// valid, iff syncDNRStartedUp
#define		RCVBUFF_SIZE 10000
CleanStringVariable(rcvBuff, RCVBUFF_SIZE);	// buffer for receiving
CleanString csRcvBuff;						// points into this buffer

int			dnsEndpointRefCounter = 0;
			// with each new asynchronous DNS request, this counter is incremented. It's
			// value will be viewed from Clean as the endpoint reference for a single asynchronous
			// DNS request.

int			select_event_possibly_happened;
			// is used in selectChC. This Boolean is set to true in the notifier function,
			// when some data or a connect request has arrived, flow is again possible
			// or when a disconnect event happened.
EndpointRef	connectingEndpoint	= 0;
			// is used to enable context switching while a "synchronous" connect happens. From
			// Clean this is seen as a blocking operation, but indeed it's implemented
			// in an asynchronous way. Before launching the connect operation, this global will
			// be set to the EndpointRef, for which the connection happens. The notifier will
			// set it to zero, when the connect operation is complete. The error code for
			// the os_connectTCP_sync function is stored in connectErrCode then.
int			connectErrCode;

void (*getNextInetEventP)(int*,int*,int*,int*); // see function WaitNextEventC
extern void (*exit_tcpip_function)();			// this function will be called when the Clean
												// program terminates

OTNotifyUPP notifierUPP = NULL;

//--------------------- FUNCTION IMPLEMENTATION -----------------------------------


#define InetEvent 24

void WaitNextEventC(int eventMask,int sleep,int mouseRgn, int in_tb,
					int *interesting,int *what,int *message,int *when,int *h,int *v,int *mods,
					int *out_tb)
// the function pointer getNextInetEventP is set to the getNextInetEvent function, when
// tcp is started up. If getNextInetEvent would be called directly, then OpenTransport had
// to be linked with every event driven Clean program 
{	
	EventRecord	myEvent;
	
	*out_tb	= in_tb;
	if (tcpStartedUp) {
		(*getNextInetEventP)(message,when,h,v);
		if (*message!=0) {
			*interesting	= true;
			*what			= InetEvent;
			*mods			= 0;
			};
		};
	if (!tcpStartedUp || *message==0) {
		*interesting	= WaitNextEvent(eventMask,&myEvent,sleep,(RgnHandle) mouseRgn);
		*what			= myEvent.what;
		*message		= myEvent.message;
		*when			= myEvent.when;
		*h				= myEvent.where.h;
		*v				= myEvent.where.v;
		*mods			= myEvent.modifiers;
		};
}

#ifndef __MACH__
// needed for WaitNextEventC
asm void __ptr_glue(void)
{
                smclass GL
                lwz             r0,0(r12)
                stw             RTOC,20(SP)
                mtctr   r0
                lwz             RTOC,4(r12)
                bctr
}
#endif

void poll(int nRChannels,EndpointRef *rChannels, dictitem **rDictitems, int *channelTypes,
		  int nSChannels,EndpointRef *sChannels, dictitem **sDictitems,
		  int *pSomething_happened)
{
	int i, state;


	//T ew_print_string(" poll(");
	*pSomething_happened	= false;
	for(i=0;i<nRChannels;i++)
		if (channelTypes[i]) {
			// the channel is a TCP_Listener
			if (rDictitems[i]->acceptInfo) {
				*pSomething_happened	= true; // a connect request is pending
				rChannels[i]			= 0;
				}
			}
		else {
			// it's a TCP_RChan
			if (data_availableC(rDictitems[i]->endpointRef)) {
				*pSomething_happened	= true;	// one can read on the channel
				rChannels[i]			= 0;
				}
			else {
				// it's a TCP_RChan where no data is pending
				state	= getEndpointStateC((int) rDictitems[i]->endpointRef);
				if (state!=T_DATAXFER && state!=T_OUTREL) {
					*pSomething_happened	= true;	// the channel is eom
					rChannels[i]			= 0;
					};						
				};
			};
	for(i=0;i<nSChannels;i++)
		if (!sDictitems[i]->channelFull) {
			*pSomething_happened	= true;		// the channel is not full
			sChannels[i]			= 0;
			}
		else {
			state	= getEndpointStateC((int) sDictitems[i]->endpointRef);
			if (state!=T_DATAXFER && state!=T_INREL) {
				*pSomething_happened	= true;	// the channel is disconnected
				sChannels[i]			= 0;
				};
			};
	//T ew_print_string(") ");
}

void selectChC(int isIOProg, int justForPC, int doTimeout, unsigned int stopTime, 
			 EndpointRef *pRChannels, int *rcvTypes, EndpointRef *pSChannels,
			 int *pErrCode)
{
	dictitem	**rDictitems,**sDictitems;
	EventRecord	my_event;
	int 		nRChannels, nSChannels,	// sizes of the passed arrays
				i,
				eventMask,
				somethingHappened, timeoutExpired;	
	unsigned int	currentTime;

	//T ew_print_string(" selectChC(");
	nRChannels	= (int) pRChannels[-2];
	nSChannels	= (int) pSChannels[-2];
	eventMask	= isIOProg ? 0 : (everyEvent-keyDownMask-keyUpMask-autoKeyMask);
	// in IO programs all events are masked out, in World programs they can be handled
	select_event_possibly_happened	= false;
	
	rDictitems	= (dictitem**) NewPtr(sizeof(dictitem**)*nRChannels);
	sDictitems	= (dictitem**) NewPtr(sizeof(dictitem**)*nSChannels);
	if (rDictitems==nil || sDictitems==nil)
		{	*pErrCode	= 3;
			return;
		};
	for(i=0;i<nRChannels;i++)
		rDictitems[i] = lookup((EndpointRef) pRChannels[i]);
	for(i=0;i<nSChannels;i++)
		sDictitems[i] = lookup((EndpointRef) pSChannels[i]);

	poll(nRChannels, pRChannels, rDictitems, rcvTypes,
		 nSChannels, pSChannels, sDictitems,
		 &somethingHappened);
	if (doTimeout)
		{	currentTime		= TickCount();
			timeoutExpired	= currentTime>stopTime;
		}
	  else
		timeoutExpired	= false;
	while (!somethingHappened && !timeoutExpired)
		{	if (WaitNextEvent (eventMask,&my_event,1,nil))
				{	if (!isIOProg && (my_event.what==updateEvt || my_event.what==mouseDown))
						handle_update_or_mouse_down_event(&my_event);
				};
			if (select_event_possibly_happened)	// this global will be set from the notifier (in generalHandler)
				{	select_event_possibly_happened	= false;
					poll(nRChannels, pRChannels, rDictitems, rcvTypes,
						 nSChannels, pSChannels, sDictitems,
						 &somethingHappened);
				};
			if (doTimeout)
				{	currentTime		= TickCount();
					timeoutExpired	= currentTime>stopTime;
				};
		};

	DisposePtr((char*) rDictitems);
	DisposePtr((char*) sDictitems);

	*pErrCode	= somethingHappened ? 0 : 1;
	// this works also if a timeout of 0 (non blocking) was used, tenzij this could cause
	// timeoutExpired to be true
	//T ew_print_string(") ");
}
 


void CS_add_deferred_events_into_queue()
{
	dictitem	*dictitemP;
	EndpointRef	endpointRef;
	
	//T ew_print_string(" CS_add_deferred_events_into_queue(");
	dictitemP	= endpointDict;
	while (dictitemP!=nil)
		{	endpointRef	= dictitemP->endpointRef;
			OTEnterNotifier(endpointRef);
			// now TWO queues are locked for access !
			if (dictitemP->deferredEvents!=nil)
				{	*toLastNext	= dictitemP->deferredEvents;
					toLastNext	= dictitemP->toLastNextDI;
					dictitemP->deferredEvents	= nil;
					dictitemP->toLastNextDI		= &(dictitemP->deferredEvents);
				};
			dictitemP	= dictitemP->next;
			OTLeaveNotifier(endpointRef);
		};
	//T ew_print_string(")#");
}

void handleDeferredEvents()
{
	//T ew_print_string(" handleDeferredEvents(");
	while(deferredEventExists)	// this global is set from the notifier
		{	inCS	= true;	// begin critical section
			deferredEventExists	= false;
				// this value might be set to true again, 
				// when this critical section is reentrantly interrupted
			CS_add_deferred_events_into_queue();
			inCS	= false;// end critical section
		};
	//T ew_print_string(")#");
}

void CS_addEventToQueue(int endpointRef,int eventCode, int receiverCategory, int misc, event ***toLastNextP)
{
	event	*new_event_p;

	new_event_p 			= (event*) OTAllocMem(sizeof(event));
	if (new_event_p==nil)
		ew_print_string("Ctcp: Cant allocate memory for TCP event");
	new_event_p->endpointRef= endpointRef;
	new_event_p->eventCode	= eventCode;
	new_event_p->receiverCategory	= receiverCategory;
	new_event_p->misc		= misc;
	new_event_p->next		= nil;

	**toLastNextP				= new_event_p;
	*toLastNextP				= &(new_event_p->next);
}


void gNextInetEvent(int *eventCode, int *endpointRef, int *receiverCategory, int *misc)
{
	if (inetEventQueue == nil)
		*eventCode = 0;
	  else
		{	event	*hoq_temp;

			// remove invalid entrys in the endpoint dictionary from time to time
			if (invalid_dictitems_exist)
				{	invalid_dictitems_exist	= false;
					remove_invalid_dictitems(&endpointDict);
				};

			inCS	= true;		// begin critical section
			*eventCode		= inetEventQueue->eventCode;
			*endpointRef	= inetEventQueue->endpointRef;
			*receiverCategory=inetEventQueue->receiverCategory;
			*misc			= inetEventQueue->misc;
			if (inetEventQueue->next==nil)
				toLastNext	= &inetEventQueue;
						
			hoq_temp		= inetEventQueue;
			inetEventQueue	= inetEventQueue->next;
			inCS	= false;	// end critical section
			
			handleDeferredEvents();
			
			OTFreeMem((char*) hoq_temp);

/*
			ew_print_string("(");
			printEvent(*eventCode);
			ew_print_string(",");
			ew_print_int((int) *endpointRef);
			ew_print_string(") transferred ");
*/
		};
}

unsigned int	tick_at_last_inet_event = 0;

void getNextInetEvent(int *eventCode, int *endpointRef, int *receiverCategory, int *misc)
{
	int	noEvent;
	unsigned int	now, time_since_last_inet_event;
	do	{
		gNextInetEvent(eventCode, endpointRef, receiverCategory, misc);
		noEvent	= *eventCode==0;
		now	= TickCount();
		time_since_last_inet_event	= now - tick_at_last_inet_event;
		}
	while (noEvent && time_since_last_inet_event<2);
	if (!noEvent)
		tick_at_last_inet_event	= now;
}

int CS_found(int endpointRef, int eventCode, event *queueP)
{
	int	found	= false;
	//T ew_print_string(" CS_found(");
	while (!found && queueP!=nil)
		{	found	= (endpointRef==queueP->endpointRef && eventCode==queueP->eventCode);
			queueP	= queueP->next;
		};
	//T ew_print_string(")#");
	return found;
}

void ensureEventInQueueC(int endpointRef, int eventCode, int receiverCategory)
// is only called from Clean, so there are no deferred events
{
	//T ew_print_string(" ensureEventInQueueC(");
	inCS	= true;		// begin critical section
	if (!CS_found(endpointRef, eventCode, inetEventQueue))
		CS_addEventToQueue(endpointRef, eventCode, receiverCategory, 0, &toLastNext);
	inCS	= false;	// end critical section
			
	handleDeferredEvents();
	//T ew_print_string(")#");
}

void StartUp()
{
	OSStatus	err;
	if (!tcpStartedUp) 
	  {	getNextInetEventP	= getNextInetEvent;
	  	err = InitOpenTransport();
		if (err!=noErr)
			IO_error("cTCP.o: can't start OpenTransport");
		csRcvBuff		= (CleanString) rcvBuff;
		exit_tcpip_function	= CleanUp;
		notifierUPP		= NewOTNotifyUPP(notifier);
		tcpStartedUp	= true;
	  };
}

void StartUpSyncDNR()
// initializes syncDNRMapper in synchronous blocking mode
{
	OSStatus	err;
	if (!syncDNRStartedUp) 
	  {	StartUp();
	  	syncDNRMapper = OTOpenMapper(OTCreateConfiguration(kDNRName), 0, &err);
		if (err!=noErr)
			ew_print_string("Ctcp: can't start DNR mapper ");
		err	= OTSetBlocking(syncDNRMapper);
		syncDNRStartedUp	= true;
	  };
}

pascal void generalHandler(	dictitem *dictitemP, void* epRef, OTEventCode eventCode)
{
	OSStatus	err;
	
	switch (eventCode)
	  {	case T_LISTEN:
			{
				TCall	 	*tcallPtr;

				tcallPtr	= OTAlloc (	(EndpointRef) epRef, T_CALL,T_ADDR | T_OPT, &err);
				if (err!=kOTNoError)
					ew_print_string("Ctcp: out of extra memory");
				
				// OTListen may be called asynchonous only in notifier !
				OTSetAsynchronous((EndpointRef) epRef);
				err = OTListen((EndpointRef) epRef, tcallPtr);
				OTSetSynchronous((EndpointRef) epRef);
				
				dictitemP->acceptInfo	= (void*) tcallPtr;
				
				select_event_possibly_happened	= true;
			}
			break;
		case T_CONNECT:
			// OTRcvConnect may be called asynchonous only in notifier!
			if (epRef==connectingEndpoint)
				{	connectingEndpoint	= 0;
					connectErrCode		= 0;
				};
			//ew_print_string("T_CONNECT");
			OTSetAsynchronous((EndpointRef) epRef);
			OTRcvConnect((EndpointRef) epRef, NULL);
			OTSetSynchronous((EndpointRef) epRef);
			break;
		case T_DISCONNECT:
			// OTRcvDisconnect may be called asynchonous only in notifier!
			OTSetAsynchronous((EndpointRef) epRef);
			OTRcvDisconnect((EndpointRef) epRef, NULL);
			OTSetSynchronous((EndpointRef) epRef);
			if (epRef==connectingEndpoint)
				{	connectingEndpoint	= 0;
					connectErrCode		= 1;
				};
			select_event_possibly_happened	= true;
			gcEndpoint((int) epRef);
			//ew_print_string("T_DISCONNECT");
			break;
		case T_ORDREL:
			// OTRcvOrderlyDisconnect may be called asynchonous only in notifier!
			OTSetAsynchronous((EndpointRef) epRef);
			OTRcvOrderlyDisconnect((EndpointRef) epRef);
			OTSetSynchronous((EndpointRef) epRef);
			select_event_possibly_happened	= true;
			gcEndpoint((int) epRef);
			//ew_print_string("T_ORDREL");
			break;
		case T_UNBINDCOMPLETE:
			invalidateDictionaryItem(dictitemP);
			//ew_print_string(" before closeProvider ");
			err = OTCloseProvider((EndpointRef) epRef);
			//ew_print_string(" after closeProvider ");
			break;
		case T_DATA:
		case T_EXDATA:
			select_event_possibly_happened	= true;
			break;
		case T_GODATA:
		case T_GOEXDATA:
			{	dictitem	*pDictitem;
				pDictitem	= lookup(epRef);
				if (pDictitem)
					pDictitem->channelFull	= 0;
				select_event_possibly_happened	= true;
			}
			break;
	  }

}
	
#define DISCONNECTED		0x0011
#define ASYNCCONNECTFAILED	0x0003


/*
void printEvent(int eventCode)
{
	switch (eventCode)
	  {	case T_LISTEN:
			ew_print_string(" T_LISTEN ");
			break;
		case T_CONNECT:
			ew_print_string(" T_CONNECT ");
			break;
		case T_DATA:
			ew_print_string(" T_DATA ");
			break;
		case T_EXDATA:
			ew_print_string(" T_EXDATA ");
			break;
		case T_DISCONNECT:
			ew_print_string(" T_DISCONNECT ");
			break;
		case T_ORDREL:
			ew_print_string(" T_ORDREL ");
			break;
		case T_GODATA:
			ew_print_string(" T_GODATA ");
			break;
		case T_GOEXDATA:
			ew_print_string(" T_GOEXDATA ");
			break;
		case T_PASSCON:
			ew_print_string(" T_PASSCON ");
			break;
		case T_UNBINDCOMPLETE:
			ew_print_string(" T_UNBINDCOMPLETE ");
			break;
		case T_LKUPNAMECOMPLETE:
			ew_print_string(" T_LKUPNAMECOMPLETE ");
			break;
		case DISCONNECTED:
			ew_print_string(" DISCONNECTED (C) ");
			break;
		case ASYNCCONNECTFAILED:
			ew_print_string(" ASYNCCONNECTFAILED (C) ");
			break;
		default:
			ew_print_string(" ");
			ew_print_int(eventCode);
			ew_print_string(" is event ");
			break;
	  };
}
*/

#define ListenerReceiver	0
#define RChanReceiver		1
#define SChanReceiver		2
#define DNSReceiver			3
#define ConnectReceiver		4

void CS_evtlAddEventToQueue(dictitem* dictitemP, OTEventCode eventCode,
							OTResult result, void* cookie, event ***toLastNextP)
{
	EndpointRef epRef;
	
	epRef	= dictitemP->endpointRef;
	if (dictitemP->hasReceiveNotifier)
		switch (eventCode)
		  {	case T_LISTEN: 
				CS_addEventToQueue((int) epRef, (int) eventCode, ListenerReceiver, 0, toLastNextP);
				break;
			case T_DATA:
			case T_EXDATA:
				CS_addEventToQueue((int) epRef, (int) T_DATA, RChanReceiver, 0, toLastNextP);
				break;
			case T_CONNECT:
				if (dictitemP->connectTCallP!=NULL)
					{	// the endpoint was asynchronously connecting
						dictitemP->tcallSaveP	= dictitemP->connectTCallP;
						dictitemP->connectTCallP	= NULL;
						OTSetSynchronous(epRef);	// set mode back to synchronous non-blocking
						// the rest of the data in *dictitemP will be set via Clean
					};
				CS_addEventToQueue((int) epRef, (int) eventCode, ConnectReceiver, 0, toLastNextP);
				break;
			case T_DISCONNECT:
				if (dictitemP->connectTCallP!=NULL)
					{	// the endpoint is asynchronously connecting
						CS_addEventToQueue((int) epRef, ASYNCCONNECTFAILED, ConnectReceiver, 0, toLastNextP);
						dictitemP->tcallSaveP	= dictitemP->connectTCallP;
						dictitemP->connectTCallP	= NULL;
						// the rest of the data in *dictitemP will be set via Clean
					}
				  else
				  	// connection is disrupted
					CS_addEventToQueue((int) epRef, (int) eventCode, RChanReceiver, 0, toLastNextP);
				break;
			case T_ORDREL:
				CS_addEventToQueue((int) epRef, (int) T_DISCONNECT, RChanReceiver, 0, toLastNextP);
				break;
			case T_LKUPNAMECOMPLETE:
				{	InetAddress	*inetAddrP;
					OTEventCode	cleanEvent;
					int			ipAddr;
					
					if (result==kOTNoError)
						{	inetAddrP	= (InetAddress*)
											 (((TLookupReply*)cookie)->names.buf+4);
											 // +4 equals 4 bytes
							cleanEvent	= T_LKUPNAMECOMPLETE;
							ipAddr		= (int) inetAddrP->fHost;
						}
					  else
						{	cleanEvent	= T_LKUPNAMECOMPLETE+1;
							ipAddr		= 0;
						};
					CS_addEventToQueue((int) dictitemP->dnsEndpointRef,(int) cleanEvent, DNSReceiver, (int) ipAddr, toLastNextP );
					// deallocate resources
					invalidateDictionaryItem(dictitemP);
			  		OTCloseProvider(epRef);

					// deallocate the memory, which was allocated in lookupHost_async.
					OTFreeMem(((TLookupReply*)cookie)->names.buf);
					OTFreeMem(cookie);
					OTFreeMem(dictitemP->lookupRequestP);
				};
				break;
		  };				
	if (dictitemP->hasSendableNotifier)
		switch (eventCode)
		  {	case T_GODATA:
				CS_addEventToQueue((int) epRef, (int) eventCode, SChanReceiver, 0, toLastNextP);
				break;
			case T_DISCONNECT:
				CS_addEventToQueue((int) epRef, DISCONNECTED, SChanReceiver, 0, toLastNextP);
				break;
		  };				
}			

void deferEvent(dictitem *dictitemP,OTEventCode eventCode,
				OTResult result, void* cookie)
{
	EndpointRef	epRef;
	
	epRef	= dictitemP->endpointRef;

	// ensure, that this routine will not be interrupted for the same endpoint
	// In this way unique acces to *dictitemP is guaranteed
	OTEnterNotifier(epRef);	
	CS_evtlAddEventToQueue(dictitemP, eventCode, result, cookie, &dictitemP->toLastNextDI);
	OTLeaveNotifier(epRef);
}


pascal void notifier(	void* dictitemP, OTEventCode eventCode,
						OTResult result, void* cookie)
{
	EndpointRef	epRef;

	epRef	= ((dictitem*)dictitemP)->endpointRef;

	generalHandler((dictitem*) dictitemP, epRef, eventCode);
		
	if (inCS)
		{	deferredEventExists	= true;
			deferEvent((dictitem*) dictitemP,eventCode,result,cookie);
		}
	  else
		{
			inCS	= true;		// begin critical section
			CS_evtlAddEventToQueue(dictitemP, eventCode, result, cookie, &toLastNext);
			inCS	= false; 	// end critical section
			
			handleDeferredEvents();
		};
}


void setupLookupParams(char *inetAddr,
					   TLookupRequest *request, TLookupReply *reply,
					   int *err)
{
	UInt8	*responseBuffer;
	int		strLength, bufferSize;
	
	OTMemzero(request, sizeof(TLookupRequest));
	strLength			= OTStrLength(inetAddr);
	request->name.buf	= (UInt8 *) inetAddr;
	request->name.len	= strLength;
	request->timeout	= 0;	// use default timeout
	request->maxcnt		= 1;
	
	bufferSize = sizeof(InetAddress)+strLength+8;
	responseBuffer		= OTAllocMem(bufferSize);
	if (responseBuffer==nil)
		*err	= 1;
	  else
		{	*err= 0;
			OTMemzero(reply, sizeof(TLookupReply));
			reply->names.buf		= responseBuffer;
			reply->names.maxlen		= bufferSize;
		}
}

void lookupHost_syncC(char* inetAddr, int *errCode, int *ipAddr)
// errCode: 0 ok, 1 not ok
{
	OSStatus		err;
	TLookupRequest	lookupRequest;
	TLookupReply	lookupReply;
	InetAddress		*inetAddrP;
	

	//T ew_print_string(" lookupHost_syncC(");
	StartUpSyncDNR();
	
	setupLookupParams(inetAddr+4, &lookupRequest, &lookupReply, errCode);
	
	if (!*errCode)
		{	err = OTLookupName(syncDNRMapper, &lookupRequest, &lookupReply);
			*errCode = err==kOTNoError ? 0 : 1;

			inetAddrP	= (InetAddress*) (lookupReply.names.buf+4);  // +4 equals 4 bytes
			*ipAddr		= (int) inetAddrP->fHost;
		};
		
	OTFreeMem(lookupReply.names.buf);
	//T ew_print_string(")#");
}

void lookupHost_asyncC(char* inetAddr, int *errCode, int *endpointRef)
// errCode: 0 ok, 1 not ok
{
	OSStatus		err;
	MapperRef		asyncDNRMapper;
	TLookupRequest	*lookupRequestP;
	TLookupReply	*lookupReplyP;
	dictitem		*dictitemP;

	//T ew_print_string(" lookupHost_asyncC(");
	StartUp();
	
	*errCode	= 1;

  	asyncDNRMapper = OTOpenMapper(OTCreateConfiguration(kDNRName), 0, &err);
	if (err!=noErr)
		ew_print_string("Ctcp: can't start DNR mapper");

	OTSetNonBlocking(asyncDNRMapper);
	OTSetAsynchronous(asyncDNRMapper);

	err	= insertNewDictionaryItem(asyncDNRMapper);
	if (err)
		return;
	setEndpointDataC((int) asyncDNRMapper, 1, 1, 0, 0);
	dictitemP	= lookup(asyncDNRMapper);
	dictitemP->dnsEndpointRef = dnsEndpointRefCounter;
	dnsEndpointRefCounter++;
	
	OTInstallNotifier(asyncDNRMapper, notifierUPP, dictitemP);

	lookupRequestP	= OTAllocMem(sizeof(TLookupRequest));
	if (lookupRequestP==nil)
		return;
	
	lookupReplyP	= OTAllocMem(sizeof(TLookupReply));
	if (lookupReplyP==nil)
		return;
	
	dictitemP->lookupRequestP	= lookupRequestP;
	// the memory obtained by *lookupRequestP will be released from within the notifier, when
	// the lookup operation has completed. The lookupReply memory will also be released there
	
	setupLookupParams(inetAddr+4, lookupRequestP, lookupReplyP, errCode);
	
	if (!*errCode)
		{	OTLookupName(asyncDNRMapper, lookupRequestP, lookupReplyP);
			*endpointRef	= (int) dictitemP->dnsEndpointRef;
		};

	//T ew_print_string(")#");

}

void createChannelEndpoint(int *errCode, EndpointRef *ep_p)
// starts up, creates an endpoint in synchronous non-blocking mode, binds it,
// inserts a new entry in the endpoint dictionary (refc=2,hSN=0,hRN=0)
// and installs the notifier. The endpoints are used for TCP_S(R)Chans only.
// errCode: 0:ok;	1:not ok
{
	OSStatus	err;
	EndpointRef	ep;
	dictitem	*dictitemP;
	
	//T ew_print_string(" createChannelEndpoint(");
	StartUp();

	*errCode = 1;
	
	ep = OTOpenEndpoint(	OTCreateConfiguration(kTCPName),
							0,nil,&err);
	if (err!=kOTNoError)
		{	ew_print_string("Ctcp: out of extra memory (2)");
			return;
		};
	
	// endpoint is now in synchronous non-blocking mode
	
	err = OTBind(ep, nil, nil);

	if (err!=kOTNoError)
		return;

	err	= insertNewDictionaryItem(ep);
	if (err)
		return;
	setEndpointDataC((int) ep, 2, 0, 0, 0);
	dictitemP	= lookup(ep);

	err	= OTInstallNotifier(ep, notifierUPP, (void*) dictitemP);
	if (err!=kOTNoError)
		return;

	*ep_p = ep;
	*errCode = 0;
	//T ew_print_string(")#");
}

void openTCP_ListenerC(int portNum, int *errCode, int *endpointRef)
// errCode: 0:ok;	1:not ok
{
	OSStatus	err;
	EndpointRef	ep;
	TBind		*reqP,
				*retP;
	dictitem	*dictitemP;

	//T ew_print_string(" openTCP_ListenerC(");
	StartUp();

	*errCode = 1;
	
	ep = OTOpenEndpoint(	OTCreateConfiguration("tilisten,tcp"),
							0,nil,&err);
	if (err!=kOTNoError)
		{	ew_print_string("Ctcp: out of extra memory (3) ");
			return;
		};

	OTSetBlocking(ep);
	
	// endpoint is now in synchronous blocking mode
	
	// now setup TBind structure
	reqP	= OTAlloc(ep, T_BIND, T_ADDR, &err);	
	if (err!=kOTNoError)
		{	ew_print_string("Ctcp: out of extra memory (4) ");
			return;
		};
	retP	= OTAlloc(ep, T_BIND, T_ADDR, &err);	
	if (err!=kOTNoError)
		{	ew_print_string("Ctcp: out of extra memory (5) ");
			return;
		};

	OTInitInetAddress((InetAddress*) reqP->addr.buf, portNum, kOTAnyInetAddress);
	reqP->addr.len	= sizeof(InetAddress);
	reqP->qlen		= 5;
	
	err = OTBind(ep, reqP, retP);
	if (err!=kOTNoError)
		return;
	
	OTFree(reqP, T_BIND);
	OTFree(retP, T_BIND);

	err	= insertNewDictionaryItem(ep);
	if (err)
		return;
	setEndpointDataC((int) ep, 1, 0, 0, 0);
	dictitemP	= lookup(ep);

	err	= OTInstallNotifier(ep, notifierUPP, (void*) dictitemP);

	if (err!=kOTNoError)
		return;
	
	*endpointRef = (int) ep;
	*errCode = 0;
	//T ew_print_string(")#");

}

void acceptC(int endpointRef, int *errCode, int *inetHostP, int *newEpRefP)
// errCode: 0:ok;	1:not ok
{
	OSStatus	err;
	dictitem	*dictitemP;
	TCall	 	*tcallP;
		
	//T ew_print_string(" acceptC(");
	dictitemP	= lookup((EndpointRef) endpointRef);

	*inetHostP = ((InetAddress*)(((TCall*) (dictitemP->acceptInfo))->addr.buf))->fHost;
	
	createChannelEndpoint(errCode,(EndpointRef*) newEpRefP);
	if (*errCode!=0)
		{	ew_print_string("Ctcp: out of extra memory (6) ");
			return;
		};
	
	tcallP					= (TCall*) dictitemP->acceptInfo;
	dictitemP->acceptInfo	= NULL;

	err = OTAccept(	(EndpointRef) endpointRef,(EndpointRef) *newEpRefP, tcallP);
	
	OTFree(tcallP, T_CALL);
	// the memory was allocated within the notifier, when getting the T_LISTEN event

	if (err!=kOTNoError)
		{	setEndpointDataC((int) *newEpRefP, 0, 0, 0, 0);
			gcEndpoint(*newEpRefP);
		};

	*errCode	= err!=kOTNoError;
	//T ew_print_string(")#");
}

void os_connectTCPC(int isIOProg, int block, int doTimeout, unsigned int stopTime, char *destination,
					int *errCode, int *timeoutExpiredP, int *endpointRefP)
// errCode: 0 ok;	1 not ok
{
	OSStatus	err;
	EndpointRef	endpointRef;
	TCall		*sndCallP;
	dictitem	*dictitemP;
	int			timeoutExpired;
	
	*timeoutExpiredP = false;	

	//T ew_print_string(" os_connectTCP_asyncC(");
	createChannelEndpoint(errCode, (EndpointRef*) endpointRefP);
	if (*errCode==0)
	  {	
		endpointRef	= (EndpointRef) *endpointRefP;
		
		// setup TCall structure 
		sndCallP	= OTAlloc(endpointRef, T_CALL, T_ADDR, &err);
		if (err!=kOTNoError)
			{	*errCode	= 1;
				return;
			};
		sndCallP->addr.len = OTInitDNSAddress((struct DNSAddress*) sndCallP->addr.buf,destination+4);
	
		// setup dictionary entry
		if (!block)
			setEndpointDataC((int) endpointRef, 1, 1, 0, 0);
			// iff the connect is not blocking, then a receiver was opened before
		dictitemP	= lookup(endpointRef);
		dictitemP->connectTCallP	= sndCallP;

		// set mode of opeartion
		OTSetNonBlocking(endpointRef);
		
		OTSetAsynchronous(endpointRef);
			
		connectingEndpoint	= endpointRef;
		// connect !
		err = OTConnect(endpointRef, sndCallP, nil);

		if (err!=kOTNoDataErr)
			{	*errCode	= 1;
				setEndpointDataC((int) endpointRef, 0, 0, 0, 0); // remove reference count
				garbageCollectEndpointC((int)endpointRef);	// and remove dictitem
				return;
			};

		// wait until connect operation completed in case of a blocking call
		if (block)
			{	EventRecord	my_event;
				int	eventMask;
				unsigned int	currentTime;
				eventMask	= isIOProg ? 0 : (everyEvent-keyDownMask-keyUpMask-autoKeyMask);
				timeoutExpired	= false;
				while (connectingEndpoint && !timeoutExpired)	// connectingEndpoint will be modified from within the notifier function
					{	if (WaitNextEvent (eventMask,&my_event,1,nil))
							{	if (!isIOProg && (my_event.what==updateEvt || my_event.what==mouseDown))
									handle_update_or_mouse_down_event(&my_event);
							};
						if (doTimeout)
							{	currentTime		= TickCount();
								timeoutExpired	= currentTime>stopTime;
							};
					}
				*errCode			= connectErrCode;
				*timeoutExpiredP	= timeoutExpired;
				if (timeoutExpired)
					{	OTSndDisconnect((EndpointRef) endpointRef, NULL);
						//	perhaps the connection was established in the meantime,
						//	so tear it down again (very rare case)
						setEndpointDataC((int) endpointRef, 0, 0, 0, 0); // remove reference count
						garbageCollectEndpointC((int) endpointRef);	// and remove dictitem
					};
			};

	  };
	//T ew_print_string(")#");
}

OTResult event_pending(EndpointRef endpointRef)
{
	OTResult	event;
	int			i;
	
	i	= 0;
	do	{	event	= OTLook((EndpointRef) endpointRef);
			i++;
			if (i>100000)
				ew_print_string("STUCK! (2) (Ctcp) ");
		}
		while (event==kOTStateChangeErr);
	return event;
}

void sendC(EndpointRef endpointRef, CleanString data, int begin, int nBytes,
			int *pErrCode, int *pSentBytes)
{
	int	n,sentBytes;
	dictitem	*pDictitem;
	char		*sendData;

	*pErrCode	= 0; 	
	if (nBytes<=0) {
		*pSentBytes	= 0;
		return;
		};
		
	sendData		= CleanStringCharacters(data)+begin;

	pDictitem	= lookup(endpointRef);
	pDictitem->channelFull	= 1;
	// The notifier might clear the channelFull flag 

	n	= OTSnd((EndpointRef) endpointRef, sendData, nBytes, 0);

	if (n>=0)
		sentBytes = n;
	  else
		sentBytes = 0;

	if (sentBytes==nBytes)
		pDictitem->channelFull	= 0;

	*pSentBytes	= sentBytes;
	
} 

int os_connectrequestavailable(int endpointRef)
{
	dictitem	*pDictitem;
	pDictitem	= lookup((EndpointRef) endpointRef);
	if (!pDictitem)
		return false;
	return (pDictitem->acceptInfo!=NULL);
}

int simple_receive(EndpointRef endpointRef, int maxSize, char* empty)
{
	OTFlags		flags;
	OTResult 	noBytes;

	do
		{	noBytes = OTRcv((EndpointRef) endpointRef, 
							(void*) empty, 
							maxSize, 
							&flags);
			if (noBytes==kOTLookErr)	// this weird case could happen when a T_GODATA or T_GOEXDATA event happened
				{	OTResult event;
					event	= OTLook((EndpointRef) endpointRef);
				};
		} while (noBytes==kOTLookErr);

	return noBytes;
}

int data_availableC(EndpointRef endpointRef)
{
	dictitem	*pDictitem;
	int			nrOfBytes;
	
	pDictitem	= lookup((EndpointRef) endpointRef);
	if (!pDictitem)
		return false;
	if (pDictitem->availByteValid)
		return true;
	nrOfBytes	= simple_receive(endpointRef, 1, &pDictitem->availByte);
	if (nrOfBytes!=1)
		return false;
	pDictitem->availByteValid	= 1;
	return true;
}


void receiveC(EndpointRef endpointRef, int maxSize, CleanString *pReceived)
// this function is only called from Clean, when it's shure, that there is some data !!
{
	dictitem	*pDictitem;
	int			size, received1, received2;
	char		*csChars;
	
	*pReceived	= csRcvBuff;
	size		= maxSize<=0 ? RCVBUFF_SIZE : (maxSize>RCVBUFF_SIZE ? RCVBUFF_SIZE : maxSize);
	csChars		= CleanStringCharacters(csRcvBuff);
	pDictitem	= lookup(endpointRef);
	if (pDictitem->availByteValid) {
		csChars[0]	= pDictitem->availByte;
		received1	= 1;
		csChars++;
		size--;
		pDictitem->availByteValid	= 0;
		}
	else
		received1	= 0;
	received2	= simple_receive(endpointRef, size, csChars);
	if (received2<0)
		received2	= 0;
	else {
		//	kOTNoDataErr did not happen => no new T_DATA event will be generated by OpenTransport,
		//	but there is data !	So the event will be generated here (this is a critical section)

		inCS	= true;		// begin critical section
		CS_evtlAddEventToQueue(pDictitem, T_DATA,0,NULL,&toLastNext);
		inCS	= false; 	// end critical section
			
		handleDeferredEvents();
		};

	CleanStringLength(csRcvBuff)	= received1+received2;
}

int getEndpointStateC(int endpointRef)
{
	OSStatus	state;
	int			i;
	
	i	= 0;
	do	{	state	= OTGetEndpointState((EndpointRef) endpointRef);
			i++;
			if (i>100000)
				ew_print_string("STUCK! (Ctcp)");
		}
		while (state==kOTStateChangeErr);
	return state;
}

void disconnectGracefulC(int endpointRef)
{
	//T ew_print_string(" disconnectGracefulC(");
	OTSndOrderlyDisconnect((EndpointRef) endpointRef);
	// behaves the same in all modes of operation
	//T ew_print_string(")#");
}

void disconnectBrutalC(int endpointRef)
{
	//T ew_print_string(" disconnectBrutalC(");
	OTSetAsynchronous((EndpointRef) endpointRef);
	OTSndDisconnect((EndpointRef) endpointRef, NULL);
	OTSetSynchronous((EndpointRef) endpointRef);
	//T ew_print_string(")#");
}

void garbageCollectEndpointC(int endpointRef)
{
	//T ew_print_string(" garbageCollectEndpointC(");
	gcEndpoint(endpointRef);
	//T ew_print_string(")#");
}

void gcEndpoint(int endpointRef)
{
	// the reference count must be zero,
	// iff an endpoint should be removed:

	dictitem	*dictitemP;
	
	dictitemP	= lookup((EndpointRef) endpointRef);
	if (dictitemP==nil)
		{	ew_print_int(endpointRef);
			ew_print_string(" not found (ERROR in gcEndpointC)");
		};
		
	if ( dictitemP->referenceCount==0 ) {
		if (dictitemP->aborted) {
			// endpoint is in T_IDLE state because a brutal disconnect was issued before:
			// unbind it the endpoint.
			OTSetAsynchronous((EndpointRef) endpointRef);
			// OTUnbind may be called asynchonous only in notifier !
			OTUnbind((EndpointRef) endpointRef);
			// closing of the endpoint and removing the dictionary item is done
			// after receiving T_UNBINDCOMPLETE
			}
		else {
			invalidateDictionaryItem(dictitemP);
			OTCloseProvider((EndpointRef) endpointRef);
			}
		};
}

int tcpPossibleC()
{
	int	err;
	long result;

	err	= Gestalt('otan',&result);
	if (err)
		return false;
	return (result & gestaltOpenTptTCPPresentMask)!=0;
}

void CleanUp()
{
	dictitem	*pDictitem;
	pDictitem	= endpointDict;
	while(pDictitem) {
		if (pDictitem->valid && pDictitem->referenceCount!=0) {
			OTUnbind((EndpointRef) pDictitem->endpointRef);
			OTCloseProvider((EndpointRef) pDictitem->endpointRef);
			pDictitem->referenceCount	= 0;
			};
		invalidateDictionaryItem(pDictitem);
		pDictitem	= pDictitem->next;
		};
	remove_invalid_dictitems(&endpointDict);
	CloseOpenTransport();
}

//------------------------ FUNCTION IMPLEMENTATIONS FOR THE ENDPOINT DICTIONARY -------

int insertNewDictionaryItem(EndpointRef endpointRef)
{
	dictitem	*newItem			= (dictitem*) NewPtr(sizeof(dictitem));
	//T ew_print_string(" insertNewDictionaryItem(");
	if (newItem==nil)
		return 1;
		
	newItem->endpointRef			= endpointRef;
	newItem->acceptInfo				= NULL;
	newItem->connectTCallP			= NULL;
	newItem->tcallSaveP				= NULL;
	newItem->next					= endpointDict;
	newItem->valid					= true;
	newItem->deferredEvents			= nil;
	newItem->toLastNextDI			= &(newItem->deferredEvents);
	newItem->availByteValid			= 0;
	newItem->aborted				= 0;
	newItem->channelFull			= 0;
	endpointDict					= newItem;

	return 0;
}

dictitem* lookup(EndpointRef endpointRef)
{
	dictitem	*ptr=endpointDict;
	while (ptr!=nil && (ptr->endpointRef!=endpointRef || (! ptr->valid)))
		ptr	= ptr->next;
	
	return ptr;
}

void setEndpointDataC(	int endpointRef, int referenceCount,
						int hasReceiveNotifier, int hasSendableNotifier, int aborted)
{
	dictitem	*ptr			= lookup((EndpointRef) endpointRef);
	
	//T ew_print_string(" setEndpointDataC(");
	if (ptr!=nil)
		{	ptr->referenceCount			= referenceCount;
			ptr->hasReceiveNotifier		= hasReceiveNotifier!=0;
			ptr->hasSendableNotifier	= hasSendableNotifier!=0;
			ptr->aborted				= aborted!=0;
		};
	//T ew_print_string(")#");
}


void getEndpointDataC(	int endpointRef, int *referenceCount,
						int *hasReceiveNotifier, int *hasSendableNotifier, int *aborted)
{
	dictitem	*ptr			= lookup((EndpointRef) endpointRef);
	
	//T ew_print_string(" getEndpointDataC(");
	if (ptr!=nil)
		{	*referenceCount			= ptr->referenceCount;
			*hasReceiveNotifier		= ptr->hasReceiveNotifier!=0;
			*hasSendableNotifier	= ptr->hasSendableNotifier!=0;
			*aborted				= ptr->aborted!=0;
		};
	//T ew_print_string(")#");
}


void removeDictionaryItem(EndpointRef endpointRef)
// the dictionary MUST contain a valid item with the endpointRef
{
	dictitem	**ptr, *temp;
	int			notRemoved;
	//T ew_print_string(" removeDictionaryItem(");

	ptr	= &endpointDict;
	notRemoved	= true;
	while(notRemoved)
		if ((*ptr)->endpointRef==endpointRef && (*ptr)->valid)
			{
				temp	= *ptr;
				*ptr	= (*ptr)->next;
				if (temp->tcallSaveP)
					OTFree(temp->tcallSaveP, T_CALL);
				//T ew_print_int((int)temp->endpointRef);
				//T ew_print_string(" is removed entry ");
				DisposePtr((char*) temp);
				notRemoved	= false;
			}
		  else
			ptr	= &((*ptr)->next);
	//T ew_print_string(")#");
}

void invalidateDictionaryItem(dictitem *dictitemP)
{
	dictitemP->valid		= false;
	invalid_dictitems_exist	= true;
}

// remove those items from the endpoint dictionary list, whose
// valid field is zero.
void remove_invalid_dictitems(dictitem **ptr)
{
	dictitem	*temp;
	int			goOn;
	
	goOn	= *ptr!=nil;
	while (goOn)
		if (!(*ptr)->valid)
			{	temp	= *ptr;
				*ptr	= temp->next;
				if (*ptr==nil)
					goOn	= false;
				if (temp->tcallSaveP)
					OTFree(temp->tcallSaveP, T_CALL);
				//T ew_print_int((int)temp->endpointRef);
				//T ew_print_string(" is invalid and removed entry ");
				DisposePtr((char*) temp);
			}
		  else
			{	if ((*ptr)->next==nil)
					goOn	= false;
				  else
					ptr		= &((*ptr)->next);
			};
}



