require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @episode = episodes(:one)
  end

  test "should get index" do
    get episodes_url
    assert_response :success
  end

  test "should get new" do
    get new_episode_url
    assert_response :success
  end

  test "should create episode" do
    assert_difference("Episode.count") do
      post episodes_url, params: { episode: { block: @episode.block, description: @episode.description, duration: @episode.duration, enclosure_length: @episode.enclosure_length, enclosure_type: @episode.enclosure_type, enclosure_url: @episode.enclosure_url, episode_number: @episode.episode_number, episode_type: @episode.episode_type, explicit: @episode.explicit, guid: @episode.guid, image_url: @episode.image_url, link: @episode.link, podcast_id: @episode.podcast_id, pub_date: @episode.pub_date, season_number: @episode.season_number, title: @episode.title, transcript_type: @episode.transcript_type, transcript_url: @episode.transcript_url } }
    end

    assert_redirected_to episode_url(Episode.last)
  end

  test "should show episode" do
    get episode_url(@episode)
    assert_response :success
  end

  test "should get edit" do
    get edit_episode_url(@episode)
    assert_response :success
  end

  test "should update episode" do
    patch episode_url(@episode), params: { episode: { block: @episode.block, description: @episode.description, duration: @episode.duration, enclosure_length: @episode.enclosure_length, enclosure_type: @episode.enclosure_type, enclosure_url: @episode.enclosure_url, episode_number: @episode.episode_number, episode_type: @episode.episode_type, explicit: @episode.explicit, guid: @episode.guid, image_url: @episode.image_url, link: @episode.link, podcast_id: @episode.podcast_id, pub_date: @episode.pub_date, season_number: @episode.season_number, title: @episode.title, transcript_type: @episode.transcript_type, transcript_url: @episode.transcript_url } }
    assert_redirected_to episode_url(@episode)
  end

  test "should destroy episode" do
    assert_difference("Episode.count", -1) do
      delete episode_url(@episode)
    end

    assert_redirected_to episodes_url
  end
end
