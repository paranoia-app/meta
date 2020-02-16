# Paranoia components

###### This paper contains ideas and details about they way things work

## How are things split?
In Paranoia, there are basically just 2 components involved, a server
and many clients. While this sounds simple, the clients themself can be
of different types, such as bots, native user clients, web user clients
and possibly more.

### Servers
Paranoia servers are endpoints which can host multiple communities. They
process messages by queueing them and then pushing them out to the
devices connected to the server. It is important to note that the server
itself can't read the messages which are being sent in direct messages.
See [the document about servers](./Servers.md) for more info.

### Clients
User clients are the ones you as a human will use to connect to one or
multiple paranoia servers and chat with people. In the end it is up to
the client to decide how it represents the contents of the servers to the
user. See [the document about clients](./Clients.md) for more info.

Bot clients on the other hand are used to allow computers to react to
user messages and take action. Currently there is no clear definition of
how those are supposed to work.