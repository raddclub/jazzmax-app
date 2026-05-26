# RaddFlix WhatsApp & Telegram Bots

## Status
- **WhatsApp bot:** In development (wa-web.js, Node.js 20)
- **Telegram bot:** Planned / early stage

## WhatsApp Bot

### Location
- **Server:** `/opt/jazzmax/wa-bot/`
- **GitHub:** `wa-bot/` folder (if present)

### Tech
- Node.js 20
- wa-web.js (WhatsApp Web automation library)
- 142 npm packages

### Purpose
- Allow users to request movie/drama links via WhatsApp
- Send subscription notifications
- Customer support automation

### How to Start/Stop
```bash
cd /opt/jazzmax/wa-bot
npm start
# or via PM2 if configured:
pm2 start index.js --name raddflix-wa-bot
```

### Status
Not yet connected to supervisor. Manual start required.
Check current state: `ps aux | grep node`

## Telegram Bot

### Status
Planned. No code yet as of 2026-05-26.

### Planned Purpose
- Mirror WhatsApp bot functionality
- Easier to deploy (official Telegram Bot API, no browser automation)
- Lower risk of bans compared to WhatsApp

## Notes for Next Agent
- WA bot uses wa-web.js which requires QR code scan on first run to link a WhatsApp account
- Session is saved locally so re-scans are rare
- If the bot gets banned, consider switching to official WhatsApp Business API
- Telegram bot should be built before expanding WA bot features (lower risk)
