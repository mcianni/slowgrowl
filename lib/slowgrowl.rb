require 'growl'

module SlowGrowl

  SLOW = 1000      # default slow alert set to 1000ms
  STICKY = false   # should error warnings be sticky?

  class Railtie < Rails::Railtie
    initializer "slowgrowl.start_plugin" do |app|
      ActiveSupport::Notifications.subscribe do |*args|

        if Growl.installed?
          event = ActiveSupport::Notifications::Event.new(*args)

          sticky = false
          action, type = event.name.split('.')
          alert = case event.duration
            when (0...SLOW) then
              false
            when (SLOW..SLOW*2) then
              :warning
            else
              sticky = STICKY
              :error
          end

          e = event.payload
          message = case type
            when 'action_controller' then
              case action
                when 'process_action' then
                  # {:controller=>"WidgetsController", :action=>"index", :params=>{"controller"=>"widgets", "action"=>"index"},
                  #  :formats=>[:html], :method=>"GET", :path=>"/widgets", :status=>200, :view_runtime=>52.25706100463867,
                  #  :db_runtime=>0}

                  if e[:exception]
                    "%s#%s.\n\n%s" % [
                      e[:controller], e[:action], e[:exception].join(', ')
                    ]
                  else
                    "%s#%s (%s).\nDB: %.1f, View: %.1f" % [
                      e[:controller], e[:action], e[:status], e[:db_runtime], e[:view_runtime]
                    ]
                  end

                else
                  '%s#%s (%s)' % [e[:controller], e[:action], e[:status]]
              end

            when 'action_view' then
              # {:identifier=>"text template", :layout=>nil }
              '%s, layout: %s' % [e[:identifier], e[:layout].nil? ? 'none' : e[:layout]]

            when 'active_record' then
              # {:sql=>"SELECT "widgets".* FROM "widgets", :name=>"Widget Load", :connection_id=>2159415800}
              "%s\n\n%s" % [e[:name], e[:sql].gsub("\n", ' ').squeeze(' ')]
            else
              'Duration: %.1f' % [event.duration]
          end

          if alert
            Growl.send("notify_#{alert}", message, {
                         :title => "%1.fms - %s : %s" % [event.duration, action.humanize, type.camelize],
                         :sticky => sticky
            })
          end
        end
      end

    end
  end
end