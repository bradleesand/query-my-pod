# == Schema Information
#
# Table name: podcast_import_tasks
#
#  id         :integer          not null, primary key
#  url        :text
#  status     :text
#  podcast_id :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_podcast_import_tasks_on_podcast_id  (podcast_id)
#

require "test_helper"

class PodcastImportTaskTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
