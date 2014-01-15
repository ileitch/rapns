module Rapns
  module Daemon
    module Store
      class ActiveRecord
        class Lock < ActiveRecord::Base
          self.table_name = 'rapns_locks'

          KEY_SEP = '_'

          # Key must contain app_ids, otherwise
          # min_old + limit may contain a non-stale app.

          def self.try_lock
          end

          def self.parse_key(key)
            return [0, 0] unless key
            min_id, limit = key.split(KEY_SEP)
            [min_id, limit].map(&:to_i)
          end

          def self.build_key(min_id, limit)
            [min_id, limit].join(KEY_SEP)
          end

          def self.key
            row = first
            row ? row.key : nil
          end
        end
      end
    end
  end
end
