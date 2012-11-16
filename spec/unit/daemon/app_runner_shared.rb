shared_examples_for "an AppRunner subclass" do
  after { Rapns::Daemon::AppRunner.runners.clear }

  describe 'start' do
    it 'initializes a handler pool' do
      handler_class.should_receive(:pool)
      runner.start
    end
  end

  describe 'deliver' do
    let(:notification) { stub }

    it 'does not deliver the notification if the pool mailbox is not empty' do
      pool.async.stub(:mailbox_size => 1)
      pool.async.should_not_receive(:deliver)
    end

    it 'delivers the notification if the pool mailbox is empty' do
      pool.async.stub(:mailbox_size => 0)
      pool.async.should_receive(:deliver).with(notification)
      runner.deliver(notification)
    end
  end

  describe 'stop' do
    before { runner.start }

    it 'terminates the pool' do
      pool.should_receive(:terminate)
      runner.stop
    end
  end

  describe 'sync' do
    before { runner.start }

    it 'reduces the number of handlers if needed' do
      pool.stub(:size => 1)
      pool.should_receive(:shrink).with(1)
      new_app = app_class.new
      new_app.stub(:connections => app.connections - 1)
      runner.sync(new_app)
    end

    it 'increases the number of handlers if needed' do
      pool.stub(:size => 1)
      pool.should_receive(:grow).with(2)
      new_app = app_class.new
      new_app.stub(:connections => app.connections + 2)
      runner.sync(new_app)
    end
  end
end
