require 'unit_spec_helper'
require 'rapns/daemon/active_record'

describe Rapns::Daemon::ActiveRecord do
  let(:app) { Rapns::Apns::App.create!(:name => 'my_app', :environment => 'development', :certificate => TEST_CERT) }
  let(:notification) { Rapns::Apns::Notification.create!(:device_token => "a" * 64, :app => app) }
  let(:backend) { Rapns::Daemon::ActiveRecord.new }
  let(:now) { Time.now }

  before { Time.stub(:now => now) }

  it 'instantiates the feeder' do
    backend.feeder.should be_kind_of(Rapns::Daemon::ActiveRecord::Feeder)
  end

  describe 'retry_after' do
    it 'increments the retry count' do
      expect do
        backend.retry_after(notification, now)
      end.to change(notification, :retries).by(1)
    end

    it 'sets the deliver after timestamp' do
      deliver_after = now + 10.seconds
      expect do
        backend.retry_after(notification, deliver_after)
      end.to change(notification, :deliver_after).to(deliver_after)
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      backend.retry_after(notification, now)
    end
  end

  describe 'mark_delivered' do
    it 'marks the notification as delivered' do
      expect do
        backend.mark_delivered(notification)
      end.to change(notification, :delivered).to(true)
    end

    it 'sets the time the notification was delivered' do
      expect do
        backend.mark_delivered(notification)
      end.to change(notification, :delivered_at).to(now)
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      backend.mark_delivered(notification)
    end
  end

  describe 'mark_failed' do
    it 'marks the notification as not delivered' do
      backend.mark_failed(notification, nil, '')
      notification.delivered.should be_false
    end

    it 'marks the notification as failed' do
      expect do
        backend.mark_failed(notification, nil, '')
      end.to change(notification, :failed).to(true)
    end

    it 'sets the time the notification delivery failed' do
      expect do
        backend.mark_failed(notification, nil, '')
      end.to change(notification, :failed_at).to(now)
    end

    it 'sets the error code' do
      expect do
        backend.mark_failed(notification, 42, '')
      end.to change(notification, :error_code).to(42)
    end

    it 'sets the error description' do
      expect do
        backend.mark_failed(notification, 42, 'Weeee')
      end.to change(notification, :error_description).to('Weeee')
    end

    it 'saves the notification without validation' do
      notification.should_receive(:save!).with(:validate => false)
      backend.mark_failed(notification, nil, '')
    end
  end

  describe 'create_apns_feedback' do
    it 'creates the Feedback record' do
      Rapns::Apns::ActiveRecord::Feedback.should_receive(:create!).with(
        :failed_at => now, :device_token => 'ab' * 32, :app => app)
      backend.create_apns_feedback(now, 'ab' * 32, app)
    end
  end

  describe 'create_gcm_notification' do
    let(:data) { { :data => true } }
    let(:attributes) { { :device_token => 'ab' * 32 } }
    let(:registration_ids) { ['123', '456'] }
    let(:deliver_after) { now + 10.seconds }
    let(:args) { [attributes, data, registration_ids, deliver_after, app] }

    it 'sets the given attributes' do
      new_notification = backend.create_gcm_notification(*args)
      new_notification.device_token.should == 'ab' * 32
    end

    it 'sets the given data' do
      new_notification = backend.create_gcm_notification(*args)
      new_notification.data['data'].should be_true
    end

    it 'sets the given registration IDs' do
      new_notification = backend.create_gcm_notification(*args)
      new_notification.registration_ids.should == registration_ids
    end

    it 'sets the deliver_after timestamp' do
      new_notification = backend.create_gcm_notification(*args)
      new_notification.deliver_after.should == deliver_after
    end

    it 'saves the new notification' do
      new_notification = backend.create_gcm_notification(*args)
      new_notification.new_record?.should be_false
    end
  end
end
