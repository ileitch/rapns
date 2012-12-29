require 'unit_spec_helper'

describe Rapns::Daemon::Gcm::Delivery do
  let(:app) { Rapns::Gcm::App.new(:name => 'MyApp', :auth_key => 'abc123') }
  let(:notification) { Rapns::Gcm::Notification.create!(:app => app,
    :registration_ids => ['xyz'], :deliver_after => Time.now) }
  let(:logger) { stub(:error => nil, :info => nil, :warn => nil) }
  let(:response) { stub(:code => 200, :header => {}) }
  let(:http) { stub(:shutdown => nil, :request => response)}
  let(:now) { Time.parse('2012-10-14 00:00:00') }
  let(:delivery) { Rapns::Daemon::Gcm::Delivery.new(app, http, notification) }
  let(:backend) { stub.as_null_object }

  def perform
    delivery.perform
  end

  before do
    Time.stub(:now => now)
    Rapns::Daemon.stub(:logger => logger, :backend => backend)
  end

  describe 'an 200 response' do
    before do
      response.stub(:code => 200)
    end

    it 'marks the notification as delivered if delivered successfully to all devices' do
      response.stub(:body => JSON.dump({ 'failure' => 0 }))
      backend.should_receive(:mark_delivered).with(notification)
      perform
    end

    it 'reflects the notification was delivered' do
      response.stub(:body => JSON.dump({ 'failure' => 0 }))
      delivery.should_receive(:reflect).with(:notification_delivered, notification)
      perform
  end

    it 'logs that the notification was delivered' do
      response.stub(:body => JSON.dump({ 'failure' => 0 }))
      logger.should_receive(:info).with("[MyApp] 1 sent to xyz")
      perform
    end

    it 'marks a notification as failed if any deliveries failed that cannot be retried.' do
      body = {
        'failure' => 1,
        'success' => 1,
        'results' => [
          { 'message_id' => '1:000' },
          { 'error' => 'NotRegistered' }
      ]}
      response.stub(:body => JSON.dump(body))
      backend.should_receive(:mark_failed).with(notification, nil,
        "Failed to deliver to all recipients. Errors: NotRegistered.")
      perform rescue Rapns::DeliveryError
    end

    describe 'all deliveries returned Unavailable or InternalServerError' do
      let(:body) {{
        'failure' => 2,
        'success' => 0,
        'results' => [
          { 'error' => 'Unavailable' },
          { 'error' => 'Unavailable' }
        ]}}

      before { response.stub(:body => JSON.dump(body)) }

      it 'retries the notification respecting the Retry-After header' do
        response.stub(:header => { 'retry-after' => 10 })
        deliver_after = now + 10.seconds
        backend.should_receive(:retry_after).with(notification, deliver_after)
        perform
      end

      it 'retries the notification using exponential back-off if the Retry-After header is not present' do
        notification.update_attribute(:retries, 8)
        deliver_after = now + 2 ** 9
        backend.should_receive(:retry_after).with(notification, deliver_after)
        perform
      end

      it 'does not mark the notification as failed' do
        backend.should_not_receive(:mark_failed)
        perform
      end

      it 'logs that the notification will be retried' do
        notification.update_attribute(:retries, 1)
        Rapns::Daemon.logger.should_receive(:warn).with("All recipients unavailable. Notification #{notification.id} will be retired after 2012-10-14 00:00:00 (retry 1).")
        perform
      end
    end

    shared_examples_for 'an notification with some delivery failures' do
      let(:new_notification) { stub(:id => 2) }

      before do
        response.stub(:body => JSON.dump(body))
        backend.stub(:create_gcm_notification => new_notification)
      end

      it 'marks the original notification as failed' do
        backend.should_receive(:mark_failed).with(notification, nil, error_description)
        perform rescue Rapns::DeliveryError
      end

      it 'reflects the notification delivery failed' do
        delivery.should_receive(:reflect).with(:notification_failed, notification)
        perform rescue Rapns::DeliveryError
      end

      it 'creates a new notification for the unavailable devices' do
        response.stub(:header => { 'retry-after' => 10 })
        notification.update_attributes(:registration_ids => ['id_0', 'id_1', 'id_2'], :data => {'one' => 1}, :collapse_key => 'thing', :delay_while_idle => true)
        backend.should_receive(:create_gcm_notification).with({"app_id" => 1, "collapse_key" => "thing", "delay_while_idle" => true}, {"one" => 1}, ["id_0", "id_2"], now + 10.seconds, app)
        perform rescue Rapns::DeliveryError
      end

      it 'raises a DeliveryError' do
        expect { perform }.to raise_error(Rapns::DeliveryError)
      end
    end

    describe 'all deliveries failed with some as Unavailable or InternalServerError' do
      let(:body) {{
        'failure' => 3,
        'success' => 0,
        'results' => [
          { 'error' => 'Unavailable' },
          { 'error' => 'NotRegistered' },
          { 'error' => 'Unavailable' }
        ]}}
      let(:error_description) { "Failed to deliver to recipients 0, 1, 2. Errors: Unavailable, NotRegistered, Unavailable. 0, 2 will be retried as notification 2." }
      it_should_behave_like 'an notification with some delivery failures'
    end
  end

  describe 'some deliveries failed with Unavailable or InternalServerError' do
    let(:body) {{
        'failure' => 2,
        'success' => 1,
        'results' => [
          { 'error' => 'Unavailable' },
          { 'message_id' => '1:000' },
          { 'error' => 'InternalServerError' }
        ]}}
    let(:error_description) { "Failed to deliver to recipients 0, 2. Errors: Unavailable, InternalServerError. 0, 2 will be retried as notification 2." }
    it_should_behave_like 'an notification with some delivery failures'
  end

  describe 'an 503 response' do
    before { response.stub(:code => 503) }

    it 'logs a warning that the notification will be retried.' do
      logger.should_receive(:warn).with("GCM responded with an Service Unavailable Error. Notification 1 will be retired after 2012-10-14 00:00:00 (retry 0).")
      perform
    end

    it 'respects an integer Retry-After header' do
      response.stub(:header => { 'retry-after' => 10 })
      backend.should_receive(:retry_after).with(notification, now + 10)
      perform
    end

    it 'respects a HTTP-date Retry-After header' do
      response.stub(:header => { 'retry-after' => 'Wed, 03 Oct 2012 20:55:11 GMT' })
      backend.should_receive(:retry_after).with(notification, Time.parse('Wed, 03 Oct 2012 20:55:11 GMT'))
      perform
    end

    it 'defaults to exponential back-off if the Retry-After header is not present' do
      backend.should_receive(:retry_after).with(notification, now + 2 ** 1)
      perform
    end

    it 'reflects the notification will be retried' do
      delivery.should_receive(:reflect).with(:notification_will_retry, notification)
      perform
    end
  end

  describe 'an 500 response' do
    before do
      notification.update_attribute(:retries, 2)
      response.stub(:code => 500)
    end

    it 'logs a warning that the notification has been re-queued.' do
      Rapns::Daemon.logger.should_receive(:warn).with("GCM responded with an Internal Error. Notification #{notification.id} will be retired after #{now.strftime("%Y-%m-%d %H:%M:%S")} (retry 2).")
      perform
    end

    it 'retries the notification with exponential back-off' do
      backend.should_receive(:retry_after).with(notification, now + 2 ** 3)
      perform
    end

    it 'reflects the notification will be retried' do
      delivery.should_receive(:reflect).with(:notification_will_retry, notification)
      perform
    end
  end

  describe 'an 401 response' do
    before { response.stub(:code => 401) }

    it 'raises an error' do
      expect { perform }.to raise_error(Rapns::DeliveryError)
    end
  end

  describe 'an 400 response' do
    before { response.stub(:code => 400) }

    it 'marks the notification as failed' do
      backend.should_receive(:mark_failed).with(notification, 400, 'GCM failed to parse the JSON request. Possibly an rapns bug, please open an issue.')
      perform rescue Rapns::DeliveryError
    end

    it 'reflects the notification delivery failed' do
      delivery.should_receive(:reflect).with(:notification_failed, notification)
      perform rescue Rapns::DeliveryError
    end
  end

  describe 'an un-handled response' do
    before { response.stub(:code => 418) }

    it 'marks the notification as failed' do
      backend.should_receive(:mark_failed).with(notification, 418, "I'm a Teapot")
      perform rescue Rapns::DeliveryError
    end

    it 'reflects the notification delivery failed' do
      delivery.should_receive(:reflect).with(:notification_failed, notification)
      perform rescue Rapns::DeliveryError
    end
  end
end
