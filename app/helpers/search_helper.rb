module SearchHelper
  # Format LLM response with clickable inline citations
  # Converts [Chunk 123] and [Episode 456] references into links
  # @param response_text [String] The LLM response text
  # @param sources [Array<Hash>] Array of source chunks with episode info
  # @return [String] HTML-safe formatted response
  def format_llm_response_with_citations(response_text, sources)
    # Build lookup maps
    chunk_lookup = sources.index_by { |source| source[:chunk]&.id }
    episode_lookup = sources.index_by { |source| source[:episode]&.id }

    # Replace [Chunk N] with clickable links
    formatted = response_text.gsub(/\[Chunk (\d+)\]/) do
      chunk_id = $1.to_i
      source = chunk_lookup[chunk_id]

      if source && source[:episode]
        link_to(
          "[Chunk #{chunk_id}]",
          episode_path(source[:episode], chunk: chunk_id),
          class: "text-decoration-none fw-semibold",
          data: { turbo_frame: "_top" },
          title: "Jump to this excerpt in #{source[:episode_title]}"
        )
      else
        # Fallback if chunk not found in sources
        "[Chunk #{chunk_id}]"
      end
    end

    # Replace [Episode N] with clickable links
    formatted = formatted.gsub(/\[Episode (\d+)\]/) do
      episode_id = $1.to_i
      source = episode_lookup[episode_id]

      if source && source[:episode]
        link_to(
          "[Episode #{episode_id}]",
          episode_path(source[:episode]),
          class: "text-decoration-none fw-semibold",
          data: { turbo_frame: "_top" },
          title: "View episode: #{source[:episode_title]}"
        )
      else
        # Fallback if episode not found in sources
        "[Episode #{episode_id}]"
      end
    end

    # Convert to simple_format for paragraph handling, then mark as html_safe
    simple_format(formatted, {}, sanitize: false)
  end
end
