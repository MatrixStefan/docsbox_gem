Gem::Specification.new do |s|
    s.name        = 'docsbox'
    s.version     = '1.0.4'
    s.date        = '2019-03-27'
    s.summary     = "DocsBox lets you drop multiple files in one record, and attach each uploaded file to its own singular record"
    s.description = "This gem was designed to make it easier to upload files to a model with 'has_many_attached', but store the files in their own records with 'has_one_attached' in their model. For example, uploading multiple photos into a photo album, where a PhotoAlbum has_many Photos"
    s.authors     = ["Stefan Ritchie"]
    s.files       = ["lib/docsbox.rb"]
    s.license       = 'MIT'
  end