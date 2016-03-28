module RecordSelect
  class Engine < Rails::Engine
    config.assets.precompile << 'record_select/next.gif' << 'record_select/previous.gif' if Rails::VERSION::MAJOR >= 4
  end
end
