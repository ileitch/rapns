require "spec_helper"

describe Rapns::Daemon::Connection do
  let(:ssl_context) { stub(:key= => nil, :cert= => nil) }
  let(:rsa_key) { stub }
  let(:certificate) { stub }
  let(:password) { stub }
  let(:x509_certificate) { stub }
  let(:host) { 'gateway.push.apple.com' }
  let(:port) { '2195' }
  let(:tcp_socket) { stub(:setsockopt => nil, :close => nil) }
  let(:ssl_socket) { stub(:sync= => nil, :connect => nil, :close => nil, :write => nil, :flush => nil) }
  let(:logger) { stub(:info => nil, :error => nil) }
  let(:connection) { Rapns::Daemon::Connection.new('Connection 0', host, port, certificate, password) }

  before do
    OpenSSL::SSL::SSLContext.stub(:new => ssl_context)
    OpenSSL::PKey::RSA.stub(:new => rsa_key)
    OpenSSL::X509::Certificate.stub(:new => x509_certificate)
    TCPSocket.stub(:new => tcp_socket)
    OpenSSL::SSL::SSLSocket.stub(:new => ssl_socket)
    Rapns::Daemon.stub(:logger => logger)
  end

  it "reads the number of bytes from the SSL socket" do
    ssl_socket.should_receive(:read).with(123)
    connection.connect
    connection.read(123)
  end

  it "selects on the SSL socket until the given timeout" do
    IO.should_receive(:select).with([ssl_socket], nil, nil, 10)
    connection.connect
    connection.select(10)
  end

  describe "when setting up the SSL context" do
    it "sets the key on the context" do
      OpenSSL::PKey::RSA.should_receive(:new).with(certificate, password).and_return(rsa_key)
      ssl_context.should_receive(:key=).with(rsa_key)
      connection.connect
    end

    it "sets the cert on the context" do
      OpenSSL::X509::Certificate.should_receive(:new).with(certificate).and_return(x509_certificate)
      ssl_context.should_receive(:cert=).with(x509_certificate)
      connection.connect
    end
  end

  describe "when connecting the socket" do
    it "creates a TCP socket using the configured host and port" do
      TCPSocket.should_receive(:new).with(host, port).and_return(tcp_socket)
      connection.connect
    end

    it "creates a new SSL socket using the TCP socket and SSL context" do
      OpenSSL::SSL::SSLSocket.should_receive(:new).with(tcp_socket, ssl_context).and_return(ssl_socket)
      connection.connect
    end

    it "sets the sync option on the SSL socket" do
      ssl_socket.should_receive(:sync=).with(true)
      connection.connect
    end

    it "connects the SSL socket" do
      ssl_socket.should_receive(:connect)
      connection.connect
    end

    it "sets the socket option TCP_NODELAY" do
      tcp_socket.should_receive(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      connection.connect
    end

    it "sets the socket option SO_KEEPALIVE" do
      tcp_socket.should_receive(:setsockopt).with(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)
      connection.connect
    end
  end

  describe "when shuting down the connection" do
    it "closes the TCP socket" do
      connection.connect
      tcp_socket.should_receive(:close)
      connection.close
    end

    it "does not attempt to close the TCP socket if it is not connected" do
      connection.connect
      tcp_socket.should_not_receive(:close)
      connection.instance_variable_set("@tcp_socket", nil)
      connection.close
    end

    it "closes the SSL socket" do
      connection.connect
      ssl_socket.should_receive(:close)
      connection.close
    end

    it "does not attempt to close the SSL socket if it is not connected" do
      connection.connect
      ssl_socket.should_not_receive(:close)
      connection.instance_variable_set("@ssl_socket", nil)
      connection.close
    end

    it "ignores IOError when the socket is already closed" do
      tcp_socket.stub(:close).and_raise(IOError)
      connection.connect
      expect { connection.close }.to_not raise_error(IOError)
    end
  end

  shared_examples_for "when the write fails" do
    before do
      connection.stub(:sleep)
      connection.connect
      ssl_socket.stub(:write).and_raise(error_type)
    end

    it "logs that the connection has been lost once only" do
      logger.should_receive(:error).with("[Connection 0] Lost connection to gateway.push.apple.com:2195 (#{error_type.name}), reconnecting...").once
      begin
        connection.write(nil)
      rescue Rapns::Daemon::ConnectionError
      end
    end

    it "retries to make a connection 3 times" do
      connection.should_receive(:reconnect).exactly(3).times
      begin
        connection.write(nil)
      rescue Rapns::Daemon::ConnectionError
      end
    end

    it "raises a ConnectionError after 3 attempts at reconnecting" do
      expect do
        connection.write(nil)
      end.to raise_error(Rapns::Daemon::ConnectionError, "Connection 0 tried 3 times to reconnect but failed (#{error_type.name}).")
    end

    it "sleeps 1 second before retrying the connection" do
      connection.should_receive(:sleep).with(1)
      begin
        connection.write(nil)
      rescue Rapns::Daemon::ConnectionError
      end
    end
  end

  describe "when write raises an Errno::EPIPE" do
    it_should_behave_like "when the write fails"

    def error_type
      Errno::EPIPE
    end
  end

  describe "when write raises an Errno::ETIMEDOUT" do
    it_should_behave_like "when the write fails"

    def error_type
      Errno::ETIMEDOUT
    end
  end

  describe "when write raises an OpenSSL::SSL::SSLError" do
    it_should_behave_like "when the write fails"

    def error_type
      OpenSSL::SSL::SSLError
    end
  end

  describe "when reconnecting" do
    it 'closes the socket' do
      connection.should_receive(:close)
      connection.send(:reconnect)
    end

    it 'connects the socket' do
      connection.should_receive(:connect_socket)
      connection.send(:reconnect)
    end
  end

  describe "when sending a notification" do
    before { connection.connect }

    it "writes the data to the SSL socket" do
      ssl_socket.should_receive(:write).with("blah")
      connection.write("blah")
    end

    it "flushes the SSL socket" do
      ssl_socket.should_receive(:flush)
      connection.write("blah")
    end
  end

  describe 'idle period' do
    before { connection.connect }

    it 'reconnects if the connection has been idle for more than the defined period' do
      Rapns::Daemon::Connection.stub(:idle_period => 0.1)
      sleep 0.2
      connection.should_receive(:reconnect)
      connection.write('blah')
    end

    it 'resets the last write time' do
      now = Time.now
      Time.stub(:now => now)
      connection.write('blah')
      connection.last_write.should == now
    end

    it 'does not reconnect if the connection has not been idle for more than the defined period' do
      connection.should_not_receive(:reconnect)
      connection.write('blah')
    end

    it 'logs the the connection is idle' do
      Rapns::Daemon::Connection.stub(:idle_period => 0.1)
      sleep 0.2
      Rapns::Daemon.logger.should_receive(:info).with('[Connection 0] Idle period exceeded, reconnecting...')
      connection.write('blah')
    end
  end
end