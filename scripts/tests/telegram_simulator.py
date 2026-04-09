import http.server
import socketserver
import json
import logging
import threading

logging.basicConfig(level=logging.INFO)

PORT = 8081
state = {
    "offset": 0,
    "messages_to_dispatch": [
        {
            "update_id": 1,
            "message": {
                "message_id": 100,
                "from": {"id": 12345},
                "chat": {"id": 12345},
                "date": 1600000000,
                "text": "Hello Indrajaal! Test command from Telegram Simulator."
            }
        }
    ]
}

class TelegramHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if "getUpdates" in self.path:
            # Parse offset
            query = self.path.split('?')
            offset = 0
            if len(query) > 1:
                params = dict(x.split('=') for x in query[1].split('&'))
                offset = int(params.get('offset', 0))

            # Return messages >= offset
            results = [m for m in state["messages_to_dispatch"] if m["update_id"] >= offset]
            
            response = {"ok": True, "result": results}
            
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
            logging.info(f"Delivered {len(results)} messages to daemon.")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if "sendMessage" in self.path:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            
            logging.info(f"🚀 [SIMULATOR] Received Outbound Telegram Message:")
            logging.info(f"   |> Chat ID: {payload.get('chat_id')}")
            logging.info(f"   |> Text:    {payload.get('text')}")
            
            # If the message asks for an ACK (via reply_markup), we queue an ACK response
            payload_str = json.dumps(payload)
            if "ACK" in payload_str:
                logging.info("   |> Found ACK request. Queuing automated simulated reply.")
                state["messages_to_dispatch"].append({
                    "update_id": state["messages_to_dispatch"][-1]["update_id"] + 1 if state["messages_to_dispatch"] else 1,
                    "message": {
                        "message_id": 101,
                        "from": {"id": 12345},
                        "chat": {"id": 12345},
                        "date": 1600000001,
                        "text": "ACK"
                    }
                })

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "result": {}}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), TelegramHandler) as httpd:
        logging.info(f"🤖 Telegram Simulator running on port {PORT}")
        httpd.serve_forever()
