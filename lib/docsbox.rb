module DocsBox
    class SortNew
        def initialize(split_from, from_attr, split_into, into_attr, params, record_data)

            @split_from = split_from
            @from_attr = from_attr
            @split_into = split_into
            @into_attr = into_attr
            @params = params
            @record_data = record_data

            @errors = valid_payload?

            if @errors.size > 0
                @errors[:operation_failed] = "Can't sort with an invalid payload. Blob(s) and attachment(s) are still associated to parent record."
                return @errors
            end
            
            sort_docs

        end

        private
        def sort_docs
            @errors = {}

            puts "@params[@split_from.class.name.underscore.to_sym] #{@params[@split_from.class.name.underscore.to_sym]}"
            puts "@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym] #{@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym]}"
            puts "@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym].class #{@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym].class}"

            if @params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym].class == String
                from_count = -1
            else
                from_count = -@params[@split_from.class.name.underscore.to_sym][@from_attr.name.to_sym].count
            end

            puts "from_count #{from_count}"

            @from_attr.attachments[from_count..-1].each do |new|
                puts "THIS ATTACHMENT: #{new.inspect}"
                puts "THIS BLOB: #{new.blob.inspect}"

                # Initialise the required_columns array
                required_columns = []

                #Initialise the required attributes hash
                accepted_data = {}

                # Check the given model for required columns (i.e. those which are marked as 'null: false' in the schema)
                # For each which is found, add it to the required_column array, unless it's the id, created_at or updated_at columns.
                @split_into.columns.each do |column|
                    if column.null == false && !(%w(id created_at updated_at).include? column.name)
                        required_columns << column
                    end
                end

                # Compare the required columns to the provided columns. If any are missing, return an error message
                required_columns.each do |column|
                    unless @record_data[column.name.to_sym].present?
                        @errors[:required_column_missing] = "You have not provided data for all required columns (i.e. those which are 'null: false' in you schema)"
                        puts "#{@errors}"
                        return @errors
                    end

                    unless types_match(@record_data[column.name.to_sym], column)
                        @errors[:required_column_type_mismatch] = "The provided data for #{column.name} of #{@record_data[column.name.to_sym]} does not match the expected type of #{column.type}"
                        puts "#{@errors}"
                        return @errors
                    end
                end

                # Populate accepted_data with @record_data key:value pairs for which there are columns in new_doc
                @split_into.columns.each do |column|
                    if @record_data[column.name.to_sym].present?
                        accepted_data[column.name.to_sym] = @record_data[column.name.to_sym]
                    end
                end

                # Override the name attribute if :use_original_filename is provided
                if @record_data[:use_original_filename].present?
                    accepted_data[@record_data[:use_original_filename].to_sym] = new.blob.filename.to_s
                end

                # Store the file size attribute if :store_filesize is provided
                if @record_data[:store_filesize].present?
                    accepted_data[@record_data[:store_filesize].to_sym] = new.blob.byte_size
                end

                # Since all required fields are present and of the correct type, we can create an empty new_doc
                if has_one
                    new_doc = @split_from
                else
                    new_doc = @split_into.new()
                end

                # Update the new_doc record with the accepted_data
                puts "Assigning accepted_data to new_doc..."
                puts "accepted_data: #{accepted_data}"
                new_doc.assign_attributes(accepted_data)
                puts "new_doc with assigned accepted_data: #{new_doc.inspect}"
                # Write the new record to the database
                if new_doc.save

                    unless new.update(name: @into_attr.to_s, record_type: @split_into.to_s, record_id: new_doc.id)
                        new.errors.each do |attr, msg|
                            @errors[:error] = msg.to_s
                        end
                        puts "77: #{@errors.inspect}"
                        return @errors
                    end

                else
                    new.errors.each do |attr, msg|
                        @errors[:error] = msg.to_s
                    end
                    puts "86: #{@errors.inspect}"
                    return @errors
                end
            end
        end

        def valid_payload?

            puts "Validating Payload..."

            @errors = {}

            puts "Validating @split_from..."
            unless @split_from.present? && @split_from.class < ApplicationRecord
                msg = "You must provide an instance variable of an ApplicationRecord as the first argument (e.g. @box)"
                @errors.merge({"payload-validation-error": msg})
            end
            puts "@split_from validation complete. Errors: #{@errors}"

            puts "Validating @from_attr..."
            unless @from_attr.present? && @from_attr.class == ActiveStorage::Attached::Many
                msg = "You must provide an ActiveStorage::Attached::Many as the second argument (e.g. @box.doc_files)"
                @errors.merge({"payload-validation-error": msg})
            end
            puts "@from_attr validation complete. Errors: #{@errors}"

            puts "Validating @split_into..."
            unless @split_into.present? && @split_into < ApplicationRecord
                msg = "You must provide a valid model (ApplicationRecord) as the third argument (e.g. Doc)"
                @errors.merge({"payload-validation-error": msg})
            end
            puts "@split_into validation complete. Errors: #{@errors}"

            puts "Validating @params..."
            unless @params.present? && @params.class == ActionController::Parameters
                msg = "You must pass your ActionController::Parameters through as the final argument"
                @errors.merge({"payload-validation-error": msg})
            end
            puts "@params validation complete. Errors: #{@errors}"

            @errors

        end

        def types_match(user_data, column)

            puts "user_data.class.to_s.underscore.to_sym: #{user_data.class.to_s.underscore.to_sym}"
            puts "user_data.class: #{user_data.class}"
            puts "column.type: #{column.type}"

            (user_data.class.to_s.underscore.to_sym == column.type) || ((["fixnum", "bignum", "integer"].include? user_data.class.to_s.downcase) && (["fixnum", "bignum", "integer"].include? column.type.to_s.downcase))
        
        end

        def has_one
            @split_from.class.name.to_s == @split_into.to_s
        end
    end
end