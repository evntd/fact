defmodule Fact.Storage.Format.Json.Test do
  use ExUnit.Case
  doctest Fact.Storage.Format.Json
  
  test "should encode an event to JSON" do    
    event = %{"type" => "TestEvent", "data" => %{ "name" => "K-2SO"}}    
    encoded_event = Fact.Storage.Format.Json.encode(event)    
    assert encoded_event == ~s({"data":{"name":"K-2SO"},"type":"TestEvent"})
  end
  
  test "should decode a JSON to an event" do
    encoded_event = ~s({"type":"TestEvent","data":{"id":123}})
    event = Fact.Storage.Format.Json.decode(encoded_event)
    assert event == %{"data" => %{ "id" => 123}, "type" => "TestEvent"}
  end
  
end