unit ZapMQ.Methods;

interface

uses
  System.Classes,
  JSON;

type
{$METHODINFO ON}
  TZapMethods = class(TComponent)
  public
    function GetMessage(const pQueueName : string) : string;
    function GetRPCResponse(const pQueueName : string; const pIdMessage : string) : string;
    function UpdateMessage(const pQueueName : string; pMessage : string) : string;
    function UpdateRPCResponse(const pQueueName : string;
      const pIdMessage : string; pResponse : string) : string;
  end;
{$METHODINFO OFF}

implementation

uses
  ZapMQ.Core, ZapMQ.Message, ZapMQ.Queue, ZapMQ.Message.JSON, System.SysUtils;

{ TZapMethods }

function TZapMethods.GetMessage(const pQueueName: string): string;
var
  Queue : TZapQueue;
  ZapMessage : TZapMessage;
  ZapJSONMessage : TZapJSONMessage;
  JSON : TJSONObject;
begin
  Result := string.Empty;
  Queue := ZapMQ.Core.Context.Queues.Find(pQueueName);
  if Assigned(Queue) then
  begin
    ZapMessage := Queue.GetNextMessageToProcess;
    if Assigned(ZapMessage) then
    begin
      ZapJSONMessage := ZapMessage.Prepare;
      try
        JSON := ZapJSONMessage.ToJSON;
        try
          Result := JSON.ToString;
          ZapMessage.Status := zSended;
        finally
          JSON.Free;
        end;
      finally
        ZapJSONMessage.Free;
      end;
    end;
  end;
end;

function TZapMethods.GetRPCResponse(const pQueueName,
  pIdMessage: string): string;
var
  Queue : TZapQueue;
  ZapMessage : TZapMessage;
begin
  Result := string.Empty;
  Queue := ZapMQ.Core.Context.Queues.Find(pQueueName);
  if Assigned(Queue) then
  begin
    ZapMessage := Queue.GetMessage(pIdMessage);
    if Assigned(ZapMessage) then
    begin
      if ZapMessage.Status = zAnswered then
      begin
        Result := ZapMessage.Response.ToString;
        ZapMessage.Status := zSended;
      end;
    end;
  end;
end;

function TZapMethods.UpdateMessage(const pQueueName : string; pMessage : string) : string;
var
  ZapMessage : TZapMessage;
  ZapJSONMessage : TZapJSONMessage;
begin
  ZapJSONMessage := TZapJSONMessage.FromJSON(pMessage);
  try
    ZapMessage := TZapMessage.Create;
    ZapMessage.QueueName := pQueueName;
    ZapMessage.TTL := ZapJSONMessage.TTL;
    ZapMessage.Body := TJSONObject.ParseJSONValue(
      TEncoding.ASCII.GetBytes(ZapJSONMessage.Body.ToString), 0) as TJSONObject;
    ZapMessage.RPC := ZapJSONMessage.RPC;
    Result := ZapMessage.Id;
    ZapMQ.Core.Context.Queues.AddMessage(ZapMessage);
  finally
    ZapJSONMessage.Free;
  end;
end;

function TZapMethods.UpdateRPCResponse(const pQueueName : string;
  const pIdMessage : string; pResponse : string): string;
var
  ZapMessage : TZapMessage;
  Queue : TZapQueue;
begin
  Result := string.Empty;
  Queue := ZapMQ.Core.Context.Queues.Find(pQueueName);
  if Assigned(Queue) then
  begin
    ZapMessage := Queue.GetMessage(pIdMessage);
    if Assigned(ZapMessage) then
    begin
      ZapMessage.Response := TJSONObject.ParseJSONValue(
        TEncoding.ASCII.GetBytes(pResponse), 0) as TJSONObject;
      ZapMessage.Status := zAnswered;
    end;
  end;
end;

end.
