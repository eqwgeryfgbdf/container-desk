#!/usr/bin/env python3
"""Local deterministic MCP server: echo only; never reads user files or runs commands."""
import json, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

mode = sys.argv[1]
calls = 0
schema = {'type':'object','properties':{'text':{'type':'string'}},'required':['text'],'additionalProperties':False}

def rpc(req):
    global calls
    method = req.get('method')
    reply = {'jsonrpc':'2.0','id':req.get('id')}
    if method == 'server/discover':
        if 'modern' in mode: result = {'supportedVersions':['2026-07-28'],'capabilities':{'tools':{}}}
        else: return {**reply,'error':{'code':-32601,'message':'Method not found'}}
    elif method == 'initialize': result = {'protocolVersion':'2025-11-25','capabilities':{'tools':{}},'serverInfo':{'name':'fixture','version':'1'}}
    elif method == 'notifications/initialized': return None
    elif method == 'tools/list': result = {'tools':[{'name':'echo','description':'Echo the exact supplied text. No side effects.','inputSchema':schema}]}
    elif method == 'tools/call':
        params=req.get('params',{})
        if params.get('name') != 'echo' or not isinstance(params.get('arguments',{}).get('text'),str):
            return {**reply,'error':{'code':-32602,'message':'Invalid arguments'}}
        calls += 1
        result={'content':[{'type':'text','text':params['arguments']['text']}],'isError':False}
    else: return {**reply,'error':{'code':-32601,'message':'Method not found'}}
    return {**reply,'result':result}

if mode.startswith('stdio'):
    for line in sys.stdin:
        req=json.loads(line)
        if 'silent' in mode: continue
        if 'oversize' in mode: print('x' * 2200000,flush=True);continue
        result=rpc(req)
        if result is not None: print(json.dumps(result),flush=True)
else:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def do_GET(self):
            value={'status':'ok'} if self.path=='/health' else {'calls':calls}
            data=json.dumps(value).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        def do_POST(self):
            req=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
            if self.path.endswith('/v1/chat/completions'):
                if self.path.startswith('/bad-tool/'):
                    result={'choices':[{'message':{'tool_calls':[{'id':'bad','type':'function','function':{'name':'invented_tool','arguments':'{}'}}]}}]}
                elif 'state' in mode and req.get('tools'):
                    name=req['tools'][0]['function']['name']
                    result={'choices':[{'message':{'role':'assistant','content':'','tool_calls':[{'id':'fixture-call','type':'function','function':{'name':name,'arguments':json.dumps({'text':'state-echo'})}}]}}]}
                else: result={'choices':[{'message':{'role':'assistant','content':'state-echo' if 'state' in mode else 'I cannot call tools.'}}]}
            elif self.path=='/redirect':
                self.send_response(307);self.send_header('Location','http://127.0.0.1:9/secret');self.end_headers();return
            elif self.path=='/auth':
                self.send_response(401);self.end_headers();return
            else:
                if 'modern' in mode:
                    assert self.headers.get('MCP-Protocol-Version')=='2026-07-28'
                    assert self.headers.get('Mcp-Method')==req['method']
                    assert req['params']['_meta']['io.modelcontextprotocol/protocolVersion']=='2026-07-28'
                    if req['method']=='tools/call': assert self.headers.get('Mcp-Name')=='echo'
                elif req['method'] not in ['server/discover','initialize']:
                    assert self.headers.get('Mcp-Session-Id')=='fixture-session'
                    assert self.headers.get('MCP-Protocol-Version')=='2025-11-25'
                result=rpc(req)
            if result is None:self.send_response(202);self.end_headers();return
            data=json.dumps(result).encode()
            sse='sse' in mode
            if sse: data=b'data: '+data+b'\n\n'
            self.send_response(200);self.send_header('Content-Type','text/event-stream' if sse else 'application/json');self.send_header('Content-Length',str(len(data)))
            if req.get('method')=='initialize':self.send_header('Mcp-Session-Id','fixture-session')
            self.end_headers();self.wfile.write(data)
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    print(str(server.server_port).ljust(31),flush=True)
    server.serve_forever()
