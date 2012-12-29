require 'unit_spec_helper'

describe Rapns::Daemon::Feeder do
  let(:config) { stub(:batch_size => 5000, :push_poll => 0, :embedded => false,
    :push => false) }
  let(:notification) { stub }
  let(:app) { stub }
  let(:logger) { stub }
  let(:feeder) { stub }
  let(:backend) { stub(:feeder => feeder) }

  before do
    feeder.stub(:each_notification).and_yield(notification)
    Rapns.stub(:config => config)
    Rapns::Daemon.stub(:backend => backend, :logger => logger)
    Rapns::Daemon::Feeder.stub(:stop? => true)
    Rapns::Daemon::AppRunner.stub(:idle => [stub(:app => app)], :enqueue => nil)
  end

  def start
    Rapns::Daemon::Feeder.start
  end

  it "starts the loop in a new thread if embedded" do
    config.stub(:embedded => true)
    Thread.should_receive(:new).and_yield
    Rapns::Daemon::Feeder.should_receive(:feed_forever)
    start
  end

  it 'enqueues notifications without looping if in push mode' do
    config.stub(:push => true)
    Rapns::Daemon::Feeder.should_not_receive(:feed_forever)
    Rapns::Daemon::Feeder.should_receive(:enqueue_notifications)
    start
  end

  it "enqueues the notification" do
    Rapns::Daemon::AppRunner.should_receive(:enqueue).with(notification)
    start
  end

  it 'reflects the notification has been enqueued' do
    Rapns::Daemon::Feeder.should_receive(:reflect).with(:notification_enqueued, notification)
    start
  end

  it "logs errors" do
    e = StandardError.new("bork")
    feeder.stub(:each_notification).and_raise(e)
    Rapns::Daemon.logger.should_receive(:error).with(e)
    start
  end

  it "interrupts sleep when stopped" do
    Rapns::Daemon::Feeder.should_receive(:interrupt_sleep)
    Rapns::Daemon::Feeder.stop
  end

  it "enqueues notifications when started" do
    Rapns::Daemon::Feeder.should_receive(:enqueue_notifications).at_least(:once)
    Rapns::Daemon::Feeder.stub(:loop).and_yield
    start
  end

  it "sleeps for the given period" do
    config.stub(:push_poll => 2)
    Rapns::Daemon::Feeder.should_receive(:interruptible_sleep).with(2)
    Rapns::Daemon::Feeder.stub(:loop).and_yield
    Rapns::Daemon::Feeder.start
  end
end
