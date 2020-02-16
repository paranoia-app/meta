# Paranoia servers
## What are they?
Servers are a collection of connections and users belonging to those.
Moreover, they queue messages and push them out to the users devices.
Speaking of messages, a server is not able to read them (at least not
for direct messages, it might be the same for groups and communities
later too). 

## Message queueing and device handling
Paranoia is a huge message queueing system. Messages are only stored on
the server as long as they have not been received by the users device.
They may also be deleted after a certain amount of time (it is up to the
server to decide how long this period is), but it is guaranteed that they
will be deleted after all devices a user has used to connected to the 
server have received them. The server has to decide which devices it
keeps (usually only the active ones) and which criteria it uses for
determining that (for example, flagging a device as inactive after 30 
days of no activity).

## About channels, posts, communities and feeds
A server can be devided into 3 simple elements: communities, channels and
posts.

### Communities
Lets first talk about communities and how they work. For those who are
familiar with discord and its guilds, imagine them as that. In case you
don't know discord and how its guild system, here is a simple 
explanation: A community is a collection of channels managed by
permissions and roles. Users may join and leave a community. This will
have the effect of them having access to the channels in this community
(if they have the needed roles and permissions). Communities can be seen
as kind of public places where people can chat. The public goes as far,
as that they can be joined via invite tickets. Such ticket may simply
be made public to allow everyone to join the community.

### Channels
Channels are a collection of posts chained together. Users which have
access to them. In a community, you need to have joined the community and
have the required permissions to access its channels. For group chats,
members of that group chat (which in return is just a channel) will have
access to it, in a direct message channel just the 2 users owning the
channel. And lastly for feeds everybody will have read access to them
but just the owner will have write access.

### Posts
Posts are which is typically refered to as messages. The reason they are
called posts is, that from the technical viewpoint, this matches their
functionality better. As such, they can contain attachments such as 
images, files and text. A post may contain only one of those elements, or
multiple at a time. It however has to contain at least one, and not every
channel will accept posts with every attachment type.

## Extra features
### Feeds
Feeds are special and are the idea of combining features of different
platforms into Paranoia as mentioned in 
[design and goals](./DesignAndGoals.md). They are channels owned by one
user but read accessible by everyone. Imagime them like Twitter channels,
as in that you can post your daily status there, or if you want the best
picture of your cat. Feeds allow us to combine what most other social
networks are based on with a chat network to create a unique experience.