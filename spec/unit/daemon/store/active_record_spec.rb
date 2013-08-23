require 'unit_spec_helper'

describe Rapns::Daemon::Store::ActiveRecord do
  let(:app) { Rapns::Apns::App.create!(:name => 'my_app', :environment => 'development', :certificate => TEST_CERT) }
  let(:notification) { Rapns::Apns::Notification.create!(:device_token => "a" * 64, :app => app) }
  let(:store) { Rapns::Daemon::Store::ActiveRecord.new }
  let(:now) { Time.now }

  before { Time.stub(:now => now) }

  describe 'deliverable_notifications' do
    it 'checks for new notifications with the ability to reconnect the database' do
      store.should_receive(:with_database_reconnect_and_retry)
      store.deliverable_notifications(app)
    end

    it 'loads notifications in batches' do
      Rapns.config.batch_size = 5000
      Rapns.config.push = false
      relation = stub.as_null_object
      relation.should_receive(:limit).with(5000)
      Rapns::Notification.stub(:ready_for_delivery => relation)
      store.deliverable_notifications([app])
    end

    it 'does not load notification in batches if in push mode' do
      Rapns.config.push = true
      relation = stub.as_null_object
      relation.should_not_receive(:limit)
      Rapns::Notification.stub(:ready_for_delivery => relation)
      store.deliverable_notifications([app])
    end

    it 'loads an undelivered notification without deliver_after set' do
      notification.update_attributes!(:delivered => false, :deliver_after => nil)
      store.deliverable_notifications([app]).should == [notification]
    end

    it 'loads an notification with a deliver_after time in the past' do
      notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.ago)
      store.deliverable_notifications([app]).should == [notification]
    end

    it 'does not load an notification with a deliver_after time in the future' do
      notification.update_attributes!(:delivered => false, :deliver_after => 1.hour.from_now)
      store.deliverable_notifications([app]).should be_empty
    end

    it 'does not load a previously delivered notification' do
      notification.update_attributes!(:delivered => true, :delivered_at => Time.now)
      store.deliverable_notifications([app]).should be_empty
    end

    it "does not enqueue a notification that has previously failed delivery" do
      notification.update_attributes!(:delivered => false, :failed => true)
      store.deliverable_notifications([app]).should be_empty
    end

    it 'does not load notifications for apps that are still processing the previous batch' do
      notification
      store.deliverable_notifications([]).should be_empty
    end
  end

  describe 'retry_after' do
    it 'increments the retry count' do
      expect do
        store.retry_after(notification, now)
      end.to change(notification, :retries).by(1)
    end

    it 'sets the deliver after timestamp' do
      deliver_after = now + 10.seconds
      expect do
        store.retry_after(notification, deliver_after)
      end.to change(notification, :deliver_after).to(deliver_after)
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      store.retry_after(notification, now)
    end
  end

  describe 'mark_delivered' do
    it 'marks the notification as delivered' do
      expect do
        store.mark_delivered(notification)
      end.to change(notification, :delivered).to(true)
    end

    it 'sets the time the notification was delivered' do
      expect do
        store.mark_delivered(notification)
      end.to change(notification, :delivered_at).to(now)
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      store.mark_delivered(notification)
    end
  end

  describe 'mark_failed' do
    it 'marks the notification as not delivered' do
      store.mark_failed(notification, nil, '')
      notification.delivered.should be_false
    end

    it 'marks the notification as failed' do
      expect do
        store.mark_failed(notification, nil, '')
      end.to change(notification, :failed).to(true)
    end

    it 'sets the time the notification delivery failed' do
      expect do
        store.mark_failed(notification, nil, '')
      end.to change(notification, :failed_at).to(now)
    end

    it 'sets the error code' do
      expect do
        store.mark_failed(notification, 42, '')
      end.to change(notification, :error_code).to(42)
    end

    it 'sets the error description' do
      expect do
        store.mark_failed(notification, 42, 'Weeee')
      end.to change(notification, :error_description).to('Weeee')
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      store.mark_failed(notification, nil, '')
    end
  end

  describe 'create_apns_feedback' do
    it 'creates the Feedback record' do
      Rapns::Apns::Feedback.should_receive(:create!).with(
        :failed_at => now, :device_token => 'ab' * 32, :app => app)
      store.create_apns_feedback(now, 'ab' * 32, app)
    end
  end

  describe 'create_gcm_notification' do
    let(:data) { { :data => true } }
    let(:attributes) { { :device_token => 'ab' * 32 } }
    let(:registration_ids) { ['123', '456'] }
    let(:deliver_after) { now + 10.seconds }
    let(:args) { [attributes, data, registration_ids, deliver_after, app] }

    it 'sets the given attributes' do
      new_notification = store.create_gcm_notification(*args)
      new_notification.device_token.should == 'ab' * 32
    end

    it 'sets the given data' do
      new_notification = store.create_gcm_notification(*args)
      new_notification.data['data'].should be_true
    end

    it 'sets the given registration IDs' do
      new_notification = store.create_gcm_notification(*args)
      new_notification.registration_ids.should == registration_ids
    end

    it 'sets the deliver_after timestamp' do
      new_notification = store.create_gcm_notification(*args)
      new_notification.deliver_after.should == deliver_after
    end

    it 'saves the new notification' do
      new_notification = store.create_gcm_notification(*args)
      new_notification.new_record?.should be_false
    end
  end
end
