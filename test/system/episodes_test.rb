require "application_system_test_case"

class EpisodesTest < ApplicationSystemTestCase
  setup do
    @episode = episodes(:one)
  end

  test "visiting the index" do
    visit episodes_url
    assert_selector "h1", text: "Episodes"
  end

  test "should create episode" do
    visit episodes_url
    click_on "New episode"

    check "Block" if @episode.block
    fill_in "Description", with: @episode.description
    fill_in "Duration", with: @episode.duration
    fill_in "Enclosure length", with: @episode.enclosure_length
    fill_in "Enclosure type", with: @episode.enclosure_type
    fill_in "Enclosure url", with: @episode.enclosure_url
    fill_in "Episode number", with: @episode.episode_number
    fill_in "Episode type", with: @episode.episode_type
    check "Explicit" if @episode.explicit
    fill_in "Guid", with: @episode.guid
    fill_in "Image url", with: @episode.image_url
    fill_in "Link", with: @episode.link
    fill_in "Podcast", with: @episode.podcast_id
    fill_in "Pub date", with: @episode.pub_date
    fill_in "Season number", with: @episode.season_number
    fill_in "Title", with: @episode.title
    fill_in "Transcript type", with: @episode.transcript_type
    fill_in "Transcript url", with: @episode.transcript_url
    click_on "Create Episode"

    assert_text "Episode was successfully created"
    click_on "Back"
  end

  test "should update Episode" do
    visit episode_url(@episode)
    click_on "Edit this episode", match: :first

    check "Block" if @episode.block
    fill_in "Description", with: @episode.description
    fill_in "Duration", with: @episode.duration
    fill_in "Enclosure length", with: @episode.enclosure_length
    fill_in "Enclosure type", with: @episode.enclosure_type
    fill_in "Enclosure url", with: @episode.enclosure_url
    fill_in "Episode number", with: @episode.episode_number
    fill_in "Episode type", with: @episode.episode_type
    check "Explicit" if @episode.explicit
    fill_in "Guid", with: @episode.guid
    fill_in "Image url", with: @episode.image_url
    fill_in "Link", with: @episode.link
    fill_in "Podcast", with: @episode.podcast_id
    fill_in "Pub date", with: @episode.pub_date.to_s
    fill_in "Season number", with: @episode.season_number
    fill_in "Title", with: @episode.title
    fill_in "Transcript type", with: @episode.transcript_type
    fill_in "Transcript url", with: @episode.transcript_url
    click_on "Update Episode"

    assert_text "Episode was successfully updated"
    click_on "Back"
  end

  test "should destroy Episode" do
    visit episode_url(@episode)
    click_on "Destroy this episode", match: :first

    assert_text "Episode was successfully destroyed"
  end
end
