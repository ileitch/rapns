require 'unit_spec_helper'
require 'rapns/daemon/active_record'

describe Rapns::Daemon::ActiveRecord::Feeder do
  let!(:app) { Rapns::Apns::App.create!(:name => 'my_app', :environment => 'development', :certificate => TEST_CERT) }
  let(:notification) { Rapns::Apns::Notification.create!(:device_token => "a" * 64, :app => app) }

  it "checks for new notifications with the ability to reconnect the database" do
    Rapns::Daemon::Feeder.should_receive(:with_database_reconnect_and_retry)
    start
  end


  it 'loads notifications in batches' do
    relation = stub.as_null_object
    relation.should_receive(:limit).with(5000)
    Rapns::Notification.stub(:ready_for_delivery => relation)
    start
  end

  it 'does not load notification in batches if in push mode' do
    config.stub(:push => true)
    relation = stub.as_null_object
    relation.should_not_receive(:limit)
    Rapns::Notification.stub(:ready_for_delivery => relation)
    start
  end

  it "enqueues an undelivered notification without deliver_after set" do
    notification.update_attributes!(:delivered => false, :deliver_after => nil)
    Rapns::Daemon::AppRunner.should_receive(:enqueue).with(notification)
    start
  end

  it "enqueues a notification with a deliver_after time in the past" do
    notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.ago)
    Rapns::Daemon::AppRunner.should_receive(:enqueue).with(notification)
    start
  end

  it "does not enqueue a notification with a deliver_after time in the future" do
    notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.from_now)
    Rapns::Daemon::AppRunner.should_not_receive(:enqueue)
    start
  end

  it "does not enqueue a previously delivered notification" do
    notification.update_attributes!(:delivered => true, :delivered_at => Time.now)
    Rapns::Daemon::AppRunner.should_not_receive(:enqueue)
    start
  end

  it "does not enqueue a notification that has previously failed delivery" do
    notification.update_attributes!(:delivered => false, :failed => true)
    Rapns::Daemon::AppRunner.should_not_receive(:enqueue)
    start
  end

  it 'does not enqueue the notification if the app runner is still processing the previous batch' do
    Rapns::Daemon::AppRunner.should_not_receive(:enqueue)
    start
  end
end
