// Kullanıcı ve asistan mesaj belgelerini (2 öğe) ve istemci yanıtını hazırlar.
const crypto = require('crypto');
const p = $('Soru: hazırla').first().json;
const reply = $('Soru: sohbet belgesi').first().json._reply;
const userMsg = p.user_message;
const now = Date.now();
const assistant = {
  id: crypto.randomUUID(), conversation_id: p.conversation.id, user_id: userMsg.user_id,
  role: 'assistant', content: reply.content, model: reply.model || null,
  seq: Math.max(now, userMsg.seq + 1), created_at: new Date(now).toISOString(),
};
const response = {
  ok: true,
  data: {
    conversation_id: p.conversation.id,
    reply: { id: assistant.id, role: 'assistant', content: assistant.content,
             model: assistant.model, model_reason: (reply.model && p.primary_model && reply.model !== p.primary_model)
               ? 'yedek model' : (p.route_reason || null), created_at: assistant.created_at },
  },
};
return [{ json: { ...userMsg, response } }, { json: assistant }];
