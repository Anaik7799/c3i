import http.server
import socketserver
import json
import logging
import base64

logging.basicConfig(level=logging.INFO)

PORT = 8082
state = {
    "messages_to_dispatch": [
        {
            "ackId": "ack-1",
            "message": {
                "data": base64.b64encode(json.dumps({
                    "space": {"name": "spaces/test-space"},
                    "message": {"text": "Hello Indrajaal! Test command from GChat Simulator."}
                }).encode()).decode(),
                "messageId": "msg-1"
            }
        }
    ]
}

class GChatHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if "pull" in self.path:
            response = {"receivedMessages": state["messages_to_dispatch"]}
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
            logging.info(f"Delivered {len(state['messages_to_dispatch'])} messages to daemon.")
            
        elif "acknowledge" in self.path:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            ack_ids = payload.get("ackIds", [])
            state["messages_to_dispatch"] = [m for m in state["messages_to_dispatch"] if m["ackId"] not in ack_ids]
            logging.info(f"Acknowledged {len(ack_ids)} messages.")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps({}).encode())
            
        elif "webhook" in self.path:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            
            logging.info(f"🚀 [SIMULATOR] Received Outbound GChat Message:")
            logging.info(f"   |> Text:    {payload.get('text')}")

            payload_str = json.dumps(payload)
            if "ACK" in payload_str:
                logging.info("   |> Found ACK request. Queuing automated simulated reply.")
                state["messages_to_dispatch"].append({
                    "ackId": f"ack-{len(state['messages_to_dispatch'])+2}",
                    "message": {
                        "data": base64.b64encode(json.dumps({
                            "space": {"name": "spaces/test-space"},
                            "message": {"text": "ACK"}
                        }).encode()).decode(),
                        "messageId": f"msg-{len(state['messages_to_dispatch'])+2}"
                    }
                })

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        # Handle Preflight check
        if "subscriptions" in self.path:
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"name": "projects/test/subscriptions/test"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), GChatHandler) as httpd:
        logging.info(f"🤖 GChat Simulator running on port {PORT}")
        httpd.serve_forever()
