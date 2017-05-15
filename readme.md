# hubot-multi-adapter

A hubot adapter that works with multiple services. For now it can send and receive **Telegram** and **socket.io** text messages.

## Install

Install using npm:

```bash
npm install hubot-multi-adapter --save
```

And then start the server with

```bash
HUBOT_SOCKETIO_PORT=9090 TELEGRAM_TOKEN=xxxx bin/hubot -a multi-adapter
```

### Telegram Setup

To get the ```TELEGRAM_TOKEN```, talk to *@bot_father* on *Telegram*.

Also set up a *webhook URL* in the *Telegram API*. First delete the old one and then set a new one. Remember that this URL has to be *HTTPS*:

```
curl -XPOST https://api.telegram.org/botXXXX/deleteWebhook
curl -XPOST https://api.telegram.org/botXXXX/setWebhook?url=https://example.com/api/telegram
```

### Webhooks

You can send **webhooks** thru this adapter using the endpoint ```/webhook```. Make sure your request has a body with the user object:

```
"user" : {
  "first_name" : "John",
  "last_name" : "Doe",
  "room" : 455098,
  "username" : "jamesperet"
  "service" : "telegram",
  "command" : "example-command"
  "msg_type" : "command"
}
```

More info on *Telegram Bots* can be found [**here**](https://core.telegram.org/bots).
