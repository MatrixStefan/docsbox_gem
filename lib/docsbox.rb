module DocsBox
    class Test
        def self.ping
            puts 'pong'
        end
    end

    class Inbox
        def initialize(box, multi_attachment, doc_model, single_attachment)
            box.multi_attachment.attachments[-params[box_symbol.to_sym][multi_attachment.to_sym].count..-1].each do |new|
                doc_model.create(box_id: box.id,
                           name: new.filename,
                           author_id: 1,
                           read: false,
                           uploader_id: 1).single_attachment.attach(new.blob)
                new.purge_later
            end
        end
    end
end