class PodcastImportTask < ApplicationRecord
  belongs_to :podcast, optional: true
end
