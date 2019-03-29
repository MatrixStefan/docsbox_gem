module DocsBox
    class Test
        def self.ping
            puts 'Pong!'
        end
    end

    class Inbox
        def initialize(split_from, from_attr, split_into, into_attr, params)

            if (defined? split_from) == "instance-variable" && split_from.class < ApplicationRecord
                # This is valid so far
            else
                puts "You must provide an instance variable of an ApplicationRecord as the first argument (e.g. @box)"
                return
            end

            if from_attr.class == ActiveStorage::Attached::Many
                # This is valid so far
            else
                puts "You must provide an ActiveStorage::Attached::Many as the second argument (e.g. @box.doc_files)"
                return
            end

            if split_into < ApplicationRecord
                # This is valid so far
            else
                puts "You must provide a valid model (ApplicationRecord) as the third argument (e.g. Doc)"
                return
            end

            if into_attr == 'test'
                # This is valid so far
            else
                puts "You must provide an ActiveStorage::Attached::One as the fourth argument (e.g. doc_file)"
                return
            end

            if params == ActionController::Parameters
                # This is valid so far
            else
                puts "You must pass your ActionController::Parameters through as the final argument"
                return
            end

            from_attr.attachments[-params[split_from.class.name.downcase.to_sym].values[0].count..-1].each do |new|
                puts "THIS ATTACHMENT: #{new.inspect}"
                Doc.create(box_id: split_from.id)
            end

        end
    end
end