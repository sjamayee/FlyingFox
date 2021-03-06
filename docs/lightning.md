Lightning payments over a N step path requires (N*4)-1 network messages.

Here's an example where N=2.

channel_manger is the channel state that your partner signed over.
channel_me is the channel state that you signed over.
arbitrage is some state that the server keeps track of. It lists 2 channels, and the hash of a bet that they share in common.

If I want to pay you through a server:

1) I tell the server I want to send the payment, and propose new channel state. And I give the server the secret encrypted so only you can read it.
* server updates channel_partner
* server updates arbitrage

2) the server finishes updating my channel by sending me a signature.
* I update channel_me
* server updates channel_me
* I update channel_partner

3) the server tells you about the payment, and starts updating your channel. The server gives you the encrypted secret.
* you update channel_me
* you update channel_partner

4) you finish updating the channel by sending a signature. And you unlock the funds by sending the secret to the server
* you update channel_partner
* server updates channel_me

// line 88 in handler.erl

5) the server acknowledges that the secret is valid by sending you a signature, which finishes updating your channel.
* you update channel_partner
* server updates channel_me

6) the server sends the secret and a signature to unlock my payment.
* server updates channel_me
* I update channel_partner

7) I acknowledge that the secret is valid by sending a signature to the server.
* server updates arbitrage
* server updates channel_partner
* I update channel_me


For a bet, both parties need to put some money at stake. This can be done trustlessly by adding a hashlock to the bet. Until the hashlock is removed, each party would get their own money back. Once the hashlock is removed, the bet becomes active.
Only the server should know the secret at first.

1) I tell the server I want to add money to the bet. I update my channel state. I send a signature and new channel state to the server. The server generates the secrethash for the hashlock.
* I update channel_me
* server updates channel_partner
* server updates arbitrage

2) The server responds by updating the channel state by giving me a signature.
* server updates channel_me
* I update channel_partner

3) The server tells you about the bet, and starts updating your channel by giving you new channel state and a signature.
* server updates channel_me
* you update channel_partner

4) you finish updating your channel, and you add more money into the bet by giving the server channel state and a signature.
* you update channel_me
* server updates channel_partner

5) The server sends you a signature for your new channel state. The bet has my money in it.
* you update channel_partner
* server updates channel_me

6) The server starts updating my channel by sending me a signature and new channel state. The server reveals the secret at this time.
* server updates channel_me
* I update channel_partner

7) I accept the channel update. I send a signature to the server.
* server updates channel_partner
* I update channel_me

8) The server shows you the secret to starts updating your channel.
* server updates channel_me
* you update channel_partner

9) you finish updating your channel by sending a signature to the server.
* server updates arbitrage
* server updates channel_partner
* you update channel_me