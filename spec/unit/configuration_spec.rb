require 'unit_spec_helper'

describe Rapns do
  let(:config) { double(:store => :active_record ) }

  before { Rapns.stub(:config => config) }

  it 'can yields a config block' do
    expect { |b| Rapns.configure(&b) }.to yield_with_args(config)
  end
end

describe Rapns::Configuration do
  let(:config) { Rapns::Configuration.new }

  it 'configures a feedback callback' do
    b = Proc.new {}
    Rapns::Deprecation.silenced do
      config.on_apns_feedback(&b)
    end
    config.apns_feedback_callback.should == b
  end

  it 'can be updated' do
    new_config = Rapns::Configuration.new
    new_config.batch_size = 100
    expect { config.update(new_config) }.to change(config, :batch_size).to(100)
  end

  it 'sets the pid_file relative if not absolute' do
    Rails.stub(:root => '/rails')
    config.pid_file = 'tmp/rapns.pid'
    config.pid_file.should == '/rails/tmp/rapns.pid'
  end

  it 'does not alter an absolute pid_file path' do
    config.pid_file = '/tmp/rapns.pid'
    config.pid_file.should == '/tmp/rapns.pid'
  end

  it 'does not allow foreground to be set to false if the platform is JRuby' do
    config.foreground = true
    Rapns.stub(:jruby? => true)
    config.foreground = false
    config.foreground.should be_true
  end
end
