require 'unit_spec_helper'

require 'rapns/daemon/store/redis_store'

describe Rapns::Daemon::Store::RedisStore, mock_redis: true do

  let(:token_prefix) { "a" * 63 }
  let(:store) { Rapns::Daemon::Store::RedisStore.new }

  before do
    Rapns::Notification.send(:include, Rapns::NotificationAsRedisObject)
    @iphone_app = Rapns::Apns::App.create!(name: 'iphone_app', environment: 'development', certificate: TEST_CERT)
    @android_app = Rapns::Gcm::App.create!(name: 'android_app', environment: 'development', auth_key: 'RANDOMAUTHKEY')
  end

  def expect_correct_notfications(expected_notifications, actual_notifications)
    expect(actual_notifications.count).to eq expected_notifications.count

    expected_notifications.each do |notif|
      actual_notif = actual_notifications.select { |n| n.device_token == notif['device_token'] }
      expect(actual_notif.first).to_not be_nil, "Expected to find a notification with device token #{notif['device_token']}."
    end
  end

  def create_notifications(number_of_notifications, &blk)
    counter = 0
    notifications = Array.new(number_of_notifications).map do
      counter += 1
      blk.call(counter)
    end
    notifications
  end

  def length_of_pending_queue
    Redis.current.llen(Rapns::Daemon::Store::RedisStore::PENDING_QUEUE_NAME)
  end

  def length_of_processing_queue
    Redis.current.zcount(Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, 3.hours.ago.utc.to_i, 1.hour.from_now.utc.to_i)
  end

  def length_of_retries_queue
    Redis.current.zcount(Rapns::Daemon::Store::RedisStore::RETRIES_QUEUE_NAME, 1.hour.ago.utc.to_i, 1.hour.from_now.utc.to_i)
  end

  def get_last_notification_from_pending_queue
    last_redis_value = Redis.current.rpop(Rapns::Daemon::Store::RedisStore::PENDING_QUEUE_NAME)
    store.build_notifications([last_redis_value]).last
  end

  def get_last_retry_from_queue
    last_redis_value = Redis.current.zrangebyscore(Rapns::Daemon::Store::RedisStore::RETRIES_QUEUE_NAME, 1.hour.ago.utc.to_i, 1.hour.from_now.utc.to_i).last
    store.build_notifications([last_redis_value]).last
  end

  def get_notifications_in_pending_queue
    redis_values = Redis.current.lrange(Rapns::Daemon::Store::RedisStore::PENDING_QUEUE_NAME, 0, length_of_pending_queue)
    store.build_notifications(redis_values)
  end

  def get_notifications_in_processing_queue
    redis_values = Redis.current.zrangebyscore(Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, '-inf', Time.now.utc.to_i)
    store.build_notifications(redis_values)
  end

  describe 'deliverable_notifications' do

    it "loads all the notifications from the pending queue" do
      expected_notifications = create_notifications(5) { |i| create_apns_notification(device_token: token_prefix + i.to_s) }

      notifications = store.deliverable_notifications(@iphone_app)
      expect_correct_notfications expected_notifications, notifications
    end

    it "removes and puts the notifications in the processing queue" do
      number_of_notifications = 5
      create_notifications(number_of_notifications) { |i| create_apns_notification(device_token: token_prefix + i.to_s) }

      expect(length_of_pending_queue).to eq number_of_notifications
      expect(length_of_processing_queue).to be_zero

      store.deliverable_notifications(@iphone_app)

      expect(length_of_pending_queue).to be_zero
      expect(length_of_processing_queue).to eq number_of_notifications
    end

    it "returns apns notification objects" do
      notification = create_apns_notification

      expected_notification = store.deliverable_notifications(@iphone_app).first
      expect(expected_notification.class).to eq Rapns::Apns::Notification
      expect(expected_notification.alert).to eq notification.alert
      expect(expected_notification.id).to eq 1
    end

    it "returns gcm notification objects" do
      notification = create_gcm_notification
      
      expected_notification = store.deliverable_notifications(@iphone_app).first
      expect(expected_notification.class).to eq Rapns::Gcm::Notification
      expect(expected_notification.data).to eq notification.data
      expect(expected_notification.id).to eq 1
    end

    it "retreives notification in batches" do
      Rapns.config.batch_size = 5
      create_notifications(Rapns.config.batch_size + 1) { |i| create_apns_notification(device_token: token_prefix + i.to_s) }

      store.deliverable_notifications(@iphone_app)

      expect(length_of_processing_queue).to eq Rapns.config.batch_size
      expect(length_of_pending_queue).to eq 1
    end

    context "has retries" do

      before do
        @number_of_retries = 5
        @number_of_retries.times do
          notif = build_apns_notification
          store.retry_after(notif, 5.minutes.ago)
        end

        @number_of_pending_retries = 3
        @number_of_pending_retries.times do
          notif = build_apns_notification
          store.retry_after(notif, 5.minutes.from_now)
        end

        expect(length_of_retries_queue).to eq (@number_of_retries + @number_of_pending_retries)
      end

      it "puts the retries that has a deliver_after time in the past into the pending queue" do
        expect(length_of_pending_queue).to eq 0

        store.deliverable_notifications(@iphone_app)

        expect(length_of_pending_queue).to eq @number_of_retries
      end

      it "puts the retries into the front of the pending queue" do
        Rapns.config.batch_size = 5
        pending_notifications = create_notifications(6) { |i| create_apns_notification(device_token: token_prefix + i.to_s) }

        store.deliverable_notifications(@iphone_app)

        notifications = get_notifications_in_pending_queue
        expect(notifications.last.id).to eq pending_notifications.last.id
      end

      it "leaves retries in the future in the retries queue" do
        store.deliverable_notifications(@iphone_app)

        expect(length_of_retries_queue).to eq @number_of_pending_retries
      end

    end

    context "has stalled notifications in processing queue" do

      before do
        stalled_notification_tolerence = 3600 #in seconds

        tolerated_score =  (Rapns.config.feedback_poll*2).seconds.ago.utc.to_i
        untolerated_score = (stalled_notification_tolerence*2).seconds.ago.utc.to_i

        @num_of_tolerated = 2
        @num_of_tolerated.times do
          notif = build_apns_notification
          Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, tolerated_score, notif.dump_redis_value
        end

        @num_of_untolerated = 3
        @num_of_untolerated.times do
          notif = build_apns_notification
          Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, untolerated_score, notif.dump_redis_value
        end
      end

      it "puts stalled notifications whose age is more than 1 feedback poll time into the pending queue" do
        expect(length_of_pending_queue).to be_zero

        store.deliverable_notifications(@iphone_app)

        expect(length_of_pending_queue).to eq @num_of_tolerated
      end

      it "puts stalled notifications into the front of the pending queue" do
        Rapns.config.batch_size = 5
        pending_notifications = create_notifications(6) { |i| create_apns_notification(device_token: token_prefix + i.to_s) }

        store.deliverable_notifications(@iphone_app)

        notifications = get_notifications_in_pending_queue
        expect(notifications.last.id).to eq pending_notifications.last.id
      end

      it "removes stalled notifications whose age is more than tolerated" do
        expect(length_of_processing_queue).to eq (@num_of_tolerated+@num_of_untolerated)

        store.deliverable_notifications(@iphone_app)

        expect(length_of_processing_queue).to be_zero
      end

      it "leaves other notifications in the processing queue" do
        score = Time.now.utc.to_i
        other_notifications = []
        other_notifications_count = 5
        other_notifications_count.times do
          notif = build_apns_notification
          other_notifications << notif
          Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, score, notif.dump_redis_value
        end

        store.deliverable_notifications(@iphone_app)

        expect(length_of_processing_queue).to eq other_notifications_count

        notifications = get_notifications_in_processing_queue
        notifications.each_index do |i|
          expect(notifications[i].id).to eq other_notifications[i].id
        end
      end

    end

  end

  describe 'retry_after' do
    let(:expected_notification) { build_apns_notification }
    let(:redis_value) { expected_notification.dump_redis_value }

    before do
      Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, redis_value
    end

    it "removes notificaiton from the processing queue into the retries queue" do
      expect(length_of_processing_queue).to eq 1
      expect(length_of_retries_queue).to be_zero

      store.retry_after(expected_notification, 5.minutes.from_now)

      expect(length_of_processing_queue).to be_zero
      expect(length_of_retries_queue).to eq 1
    end

    it "gives the correct score" do
      retry_time = 5.minutes.from_now
      store.retry_after(expected_notification, retry_time)

      actual_score = Redis.current.zscore(Rapns::Daemon::Store::RedisStore::RETRIES_QUEUE_NAME, expected_notification.dump_redis_value)
      expect(actual_score).to eq retry_time.utc.to_i
    end

    it "removes the correct notificaton from processing queue" do
      other_notifications_count = 2
      other_notifications_count.times do
        notif =  build_apns_notification
        Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, notif.dump_redis_value
      end

      store.retry_after(expected_notification, 5.minutes.from_now)

      expect(length_of_processing_queue).to eq other_notifications_count

      notifications_in_processing_queue = get_notifications_in_processing_queue
      notifications_in_processing_queue.each do |notif|
        expect(notif.id).to_not eq expected_notification.id
      end
    end

    it "inserts the correct notification into the retries queue" do
      other_notifications_count = 2
      other_notifications_count.times do
        notif = build_apns_notification
        Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, notif.dump_redis_value
      end

      store.retry_after(expected_notification, 5.minutes.from_now)

      notification = get_last_retry_from_queue
      expect(notification.id).to eq expected_notification.id
    end

    it 'increments the retry count' do
      expect(expected_notification.retries).to be_zero

      store.retry_after(expected_notification, 5.minutes.from_now)

      notification = get_last_retry_from_queue

      expect(notification.retries).to eq 1
    end

    it 'sets the deliver after timestamp' do
      expect(expected_notification.deliver_after).to be_nil

      retry_time = 5.minutes.from_now
      store.retry_after(expected_notification, retry_time)

      notification = get_last_retry_from_queue

      expect(notification.deliver_after.utc.to_i).to eq retry_time.utc.to_i
    end

  end

  describe 'mark_delivered' do

    before do
      @notification = build_apns_notification
      Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, @notification.dump_redis_value
    end

    it "removes the notification from the processing queue" do
      expect(length_of_processing_queue).to eq 1

      store.mark_delivered(@notification)

      expect(length_of_processing_queue).to be_zero
    end

    it "removes the correct notification" do
      create_notifications(2) do |i|
        notification = build_apns_notification
        Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, notification.dump_redis_value
      end

      store.mark_delivered(@notification)

      notifications = get_notifications_in_processing_queue
      notifications.each do |notif|
        expect(notif.id).to_not eq @notification.id
      end
    end

  end

  describe 'mark_failed' do

    let(:notification) { build_apns_notification }

    it "removes the notification from the processing queue" do
      Redis.current.zadd Rapns::Daemon::Store::RedisStore::PROCESSING_QUEUE_NAME, Time.now.utc.to_i, notification.dump_redis_value
      expect(length_of_processing_queue).to eq 1
      store.mark_failed(notification, nil, '')
      expect(length_of_processing_queue).to be_zero
    end

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
      end.to change(notification, :failed_at).to be_within(1.second).of(Time.now)
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
      notification.should_receive(:save).with(:validate => false)
      store.mark_failed(notification, nil, '')
    end

    it "skips saving the failed notification if already exists" do
      store.mark_failed(notification, nil, '')
      expect {
        store.mark_failed(notification, nil, '')
      }.to_not change(Rapns::Notification, :count)
    end

  end

  describe 'create_apns_feedback' do
    it 'creates the Feedback record' do
      now = Time.now
      Rapns::Apns::Feedback.should_receive(:create!).with(
        :failed_at => now, :device_token => 'ab' * 32, :app => @iphone_app)
      store.create_apns_feedback(now, 'ab' * 32, @iphone_app)
    end
  end

  describe 'create_gcm_notification' do
    let(:data) { { :data => true } }
    let(:attributes) { { :device_token => 'ab' * 32 } }
    let(:registration_ids) { ['123', '456'] }
    let(:deliver_after) { Time.now + 10.seconds }
    let(:args) { [attributes, data, registration_ids, deliver_after, @android_app] }

    it 'sets the given attributes' do
      new_notification = store.create_gcm_notification(*args)
      expect(new_notification.device_token).to eq 'ab' * 32
    end

    it 'sets the given data' do
      new_notification = store.create_gcm_notification(*args)
      expect(new_notification.data['data']).to be_true
    end

    it 'sets the given registration IDs' do
      new_notification = store.create_gcm_notification(*args)
      expect(new_notification.registration_ids).to eq registration_ids
    end

    it 'sets the deliver_after timestamp' do
      new_notification = store.create_gcm_notification(*args)
      expect(new_notification.deliver_after).to be_within(1.second).of(deliver_after)
    end

    it 'saves the new notification' do
      expect(length_of_pending_queue).to be_zero
      store.create_gcm_notification(*args)
      expect(length_of_pending_queue).to eq 1
    end

  end

  def build_apns_notification(options={})
    notification = Rapns::Apns::Notification.new(app: @iphone_app)
    notification.id = Redis.current.incr('rapns:notifications:counter')
    notification.device_token = options[:device_token] || token_prefix + "0"
    notification.alert = options[:alert] || "Roomorama rocks!"
    notification
  end

  def build_gcm_notification(options={})
    notification = Rapns::Gcm::Notification.new(app: @android_app)
    notification.id = Redis.current.incr('rapns:notifications:counter')
    notification.registration_ids = [(options[:registration_id] || token_prefix + "0")]
    notification.data = {message: options[:message] || "Roomorama rocks!"}
    notification
  end

  def create_apns_notification(options={})
    notification = build_apns_notification(options)
    notification.save_to_redis
    notification
  end

  def create_gcm_notification(options={})
    notification = build_gcm_notification(options)
    notification.save_to_redis
    notification
  end

end
