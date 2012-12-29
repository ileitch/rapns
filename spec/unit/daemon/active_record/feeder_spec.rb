require 'unit_spec_helper'
require 'rapns/daemon/active_record'

describe Rapns::Daemon::ActiveRecord::Feeder do
  let(:app) { Rapns::Apns::App.create!(:name => 'my_app', :environment => 'development', :certificate => TEST_CERT) }
  let(:notification) { Rapns::Apns::Notification.create!(:device_token => "a" * 64, :app => app) }
  let(:feeder) { Rapns::Daemon::ActiveRecord::Feeder.new }

  it 'checks for new notifications with the ability to reconnect the database' do
    feeder.should_receive(:with_database_reconnect_and_retry)
    feeder.notifications(app)
  end

  it 'loads notifications in batches' do
    relation = stub.as_null_object
    relation.should_receive(:limit).with(5000)
    Rapns::Notification.stub(:ready_for_delivery => relation)
    feeder.notifications([app])
  end

  it 'does not load notification in batches if in push mode' do
    Rapns.config.push = true
    relation = stub.as_null_object
    relation.should_not_receive(:limit)
    Rapns::Notification.stub(:ready_for_delivery => relation)
    feeder.notifications([app])
  end

  it 'loads an undelivered notification without deliver_after set' do
    notification.update_attributes!(:delivered => false, :deliver_after => nil)
    feeder.notifications([app]).should == [notification]
  end

  it 'loads an notification with a deliver_after time in the past' do
    notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.ago)
    feeder.notifications([app]).should == [notification]
  end

  it 'does not load an notification with a deliver_after time in the future' do
    notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.from_now)
    feeder.notifications([app]).should be_empty
  end

  it 'does not load a previously delivered notification' do
    notification.update_attributes!(:delivered => true, :delivered_at => Time.now)
    feeder.notifications([app]).should be_empty
  end

  it "does not enqueue a notification that has previously failed delivery" do
    notification.update_attributes!(:delivered => false, :failed => true)
    feeder.notifications([app]).should be_empty
  end

  it 'does not load notifications for apps that are still processing the previous batch' do
    notification
    feeder.notifications([]).should be_empty
  end
end
