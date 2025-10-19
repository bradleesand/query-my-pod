# == Schema Information
#
# Table name: podcasts
#
#  id          :integer          not null, primary key
#  rss_url     :text
#  title       :text             not null
#  description :text
#  link        :text
#  language    :text
#  category    :text
#  explicit    :boolean
#  image_url   :text
#  guid        :text             not null
#  author      :text
#  copywrite   :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_podcasts_on_guid  (guid) UNIQUE
#

class Podcast < ApplicationRecord
  has_many :episodes, dependent: :destroy
end
