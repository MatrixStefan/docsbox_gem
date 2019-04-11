module DocsBox
    class SortNew
        def initialize(split_from, from_attr, split_into, into_attr, params, record_data) # Problem?

            @split_from = split_from
            @from_attr = from_attr
            @split_into = split_into
            @into_attr = into_attr
            @params = params
            @record_data = record_data
            debug_output("@split_from = #{@split_from}")
            debug_output("@from_attr = #{@from_attr}")
            debug_output("@split_into = #{@split_into}")
            debug_output("@into_attr = #{@into_attr}")
            debug_output("@params = #{@params}")
            debug_output("@record_data = #{@record_data}")

            @errors = valid_payload?
            debug_output("We have #{@errors.size} errors")

            if @errors.size > 0
                debug_output("Since there were errors, we return them in the @errors object, which an overarching error included")
                @errors[:operation_failed] = "Can't sort with an invalid payload. Blob(s) and attachment(s) are still associated to parent record."
                return @errors
            end
            
            debug_output("So far so good! Let's try and sort the docs...")
            sort_docs

        end

        private
        def sort_docs
            @errors = {}
            
            debug_output("We can see #{-attachments_count} attachment record(s) to work")

            @from_attr.attachments[attachments_count..-1].each do |new|
                debug_output("THIS ATTACHMENT: #{new.inspect}")
                debug_output("THIS BLOB: #{new.blob.inspect}")

                @required_columns = []
                build_required_columns

                debug_output("These are our required columns: #{@required_columns}")
                debug_output("Next we make sure each of the required columns has been provided as an argument, and whether its value is of the appropriate type")

                compare_given_columns_to_required_columns

                debug_output("We also need to filter out any data which isn't acceptable (i.e. columns which don't exist in this model)")
                debug_output("We do that by interating through each column in the #{@split_into.name} model and checking for its presence in @record_data")
                @accepted_data = {}
                populate_accepted_data

                filename_override(new)

                filesize_override(new)

                # Since all required fields are present and of the correct type, we can create an empty new_doc
                if has_one
                    debug_output("This appears to be a has_one_attached case")
                    new_doc = @split_from
                else
                    new_doc = @split_into.new()
                end

                # Update the new_doc record with the @accepted_data
                debug_output("Assigning @accepted_data to new_doc...")
                debug_output("@accepted_data: #{@accepted_data}")
                new_doc.assign_attributes(@accepted_data)
                debug_output("new_doc with assigned @accepted_data: #{new_doc.inspect}")
                # Write the new record to the database
                if new_doc.save

                    unless new.update(name: @into_attr.to_s, record_type: @split_into.to_s, record_id: new_doc.id)
                        new.errors.each do |attr, msg|
                            @errors[:error] = msg.to_s
                        end
                        debug_output("77: #{@errors.inspect}")
                        return @errors
                    end

                else
                    new.errors.each do |attr, msg|
                        @errors[:error] = msg.to_s
                    end
                    debug_output("86: #{@errors.inspect}")
                    return @errors
                end
            end
        end

        def valid_payload? #Not the problem

            debug_output("Validating Payload...")

            @errors = {}

            debug_output("Validating @split_from...")
            unless @split_from.present? && @split_from.class < ApplicationRecord
                msg = "You must provide an instance variable of an ApplicationRecord as the first argument (e.g. @box)"
                @errors.merge({"payload-validation-error": msg})
            end
            debug_output("@split_from validation complete. Errors: #{@errors}")

            debug_output("Validating @from_attr...")
            unless ((@from_attr.present?) && ((@from_attr.class == ActiveStorage::Attached::Many) || (@from_attr.class == ActiveStorage::Attached::One)))
                msg = "You must provide an ActiveStorage::Attached::Many as the second argument (e.g. @box.doc_files)"
                @errors.merge({"payload-validation-error": msg})
            end
            debug_output("@from_attr validation complete. Errors: #{@errors}")

            debug_output("Validating @split_into...")
            unless @split_into.present? && @split_into < ApplicationRecord
                msg = "You must provide a valid model (ApplicationRecord) as the third argument (e.g. Doc)"
                @errors.merge({"payload-validation-error": msg})
            end
            debug_output("@split_into validation complete. Errors: #{@errors}")

            debug_output("Validating @params...")
            unless @params.present? && @params.class == ActionController::Parameters
                msg = "You must pass your ActionController::Parameters through as the final argument"
                @errors.merge({"payload-validation-error": msg})
            end
            debug_output("@params validation complete. Errors: #{@errors}")

            @errors

        end

        def types_match(user_data, column) # Not the problem

            debug_output("user_data.class.to_s.underscore.to_sym: #{user_data.class.to_s.underscore.to_sym}")
            debug_output("user_data.class: #{user_data.class}")
            debug_output("column.type: #{column.type}")

            (user_data.class.to_s.underscore.to_sym == column.type) || ((["fixnum", "bignum", "integer"].include? user_data.class.to_s.downcase) && (["fixnum", "bignum", "integer"].include? column.type.to_s.downcase))
        
        end

        def has_one # Not the problem
            debug_output("At this stage we check whether the 1st argument is a has_one_attached")
            @from_attr.class == ActiveStorage::Attached::One
        end

        def debug_output(msg)
            if @record_data[:debug].present?
                puts "<#> DocsBox Debug: #{msg}"
            end
        end

        def attachments_count # Not the problem
            if has_one
                -1
            else
                -@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym].count
            end
        end

        def build_required_columns
            # Check the given model for required columns (i.e. those which are marked as 'null: false' in the schema)
            # For each which is found, add it to the required_column array, unless it's the id, created_at or updated_at columns.
            @split_into.columns.each do |column|
                if column.null == false && !(%w(id created_at updated_at).include? column.name)
                    debug_output("It looks like #{column.name} has been defined as a required column in the #{@split_into.name} model, so we add it to the 'required_column' array")
                    @required_columns << column
                end
            end
        end

        def compare_given_columns_to_required_columns
            # Compare the required columns to the provided columns. If any are missing, return an error message
            @required_columns.each do |column|
                unless @record_data[column.name.to_sym].present?
                    @errors[:required_column_missing] = "You have not provided data for all required columns (i.e. those which are 'null: false' in you schema)"
                    debug_output("#{@errors}")
                    return @errors
                end

                unless types_match(@record_data[column.name.to_sym], column)
                    @errors[:required_column_type_mismatch] = "The provided data for #{column.name} of #{@record_data[column.name.to_sym]} does not match the expected type of #{column.type}"
                    debug_output("#{@errors}")
                    return @errors
                end
            end
        end

        def populate_accepted_data
            # Populate accepted_data with @record_data key:value pairs for which there are columns in new_doc
            @split_into.columns.each do |column|
                if @record_data[column.name.to_sym].present?
                    debug_output("Since @record_data[#{column.name.to_sym}] is present, we add its value to our accepted_data hash")
                    @accepted_data[column.name.to_sym] = @record_data[column.name.to_sym]
                end
            end
            @accepted_data
        end

        def filename_override(new)
            # Override the name attribute if :use_original_filename is provided
            if @record_data[:use_original_filename].present?
                debug_output("It looks like we want to use the originally uploaded file's filename, so we add/overwrite accepted_data[#{@record_data[:use_original_filename].to_sym}] accordingly")
                @accepted_data[@record_data[:use_original_filename].to_sym] = new.blob.filename.to_s
            end
        end

        def filesize_override(new)
            # Store the file size attribute if :store_filesize is provided
            if @record_data[:store_filesize].present?
                debug_output("It looks like we want to use the originally uploaded file's byte_size, so we add/overwrite accepted_data[#{@record_data[:store_filesize].to_sym}] accordingly")
                @accepted_data[@record_data[:store_filesize].to_sym] = new.blob.byte_size
            end
        end
    end
end