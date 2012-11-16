require 'unit_spec_helper'

describe Rapns::Daemon::Apns::DeliveryHandler do
  let(:name) { 'MyApp' }
  let(:host) { 'localhost' }
  let(:port) { 2195 }
  let(:certificate) { stub }
  let(:password) { stub }
  let(:app) { stub(:password => password, :certificate => certificate, :name => name)}
  let(:delivery_handler) { Rapns::Daemon::Apns::DeliveryHandler.new(app, host, port) }
  let(:connection) { stub('Connection', :select => false, :write => nil, :reconnect => nil, :close => nil, :connect => nil) }
  let(:notification) { stub }
  let(:http) { stub(:shutdown => nil)}

  before do
    Rapns::Daemon::Apns::Connection.stub(:new => connection)
    Rapns::Daemon::Apns::Delivery.stub(:perform)
  end

  it "instantiates a new connection" do
    Rapns::Daemon::Apns::Connection.should_receive(:new).with(app, host, port).and_return(connection)
    delivery_handler = Rapns::Daemon::Apns::DeliveryHandler.new(app, host, port)
    delivery_handler.terminate
  end

  it 'performs delivery of an notification' do
    Rapns::Daemon::Apns::Delivery.should_receive(:perform).with(app, connection, notification)
    delivery_handler.deliver(notification)
    delivery_handler.terminate
  end

  it "connects the socket when instantiated" do
    connection.should_receive(:connect)
    delivery_handler = Rapns::Daemon::Apns::DeliveryHandler.new(app, host, port)
    delivery_handler.terminate
  end

  it 'closes the connection when finalized' do
    connection.should_receive(:close)
    delivery_handler.terminate
  end
end
