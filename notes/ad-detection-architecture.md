# Ad Detection Architecture

## Overview

Detect and remove ads from podcast episodes using audio cue matching. Users identify ad start/end cues once, then the system automatically removes ads from all episodes.

## Key Challenges

### 1. Dynamic Ad Insertion (DAI)
Podcast hosts serve different audio files with different ads to different users/times. This means:
- We must **download and store episodes locally** for consistent playback
- Can't rely on URL alone - must store actual audio file
- Need media server to serve our edited versions

### 2. Overlapping Audio
Audio cues often have talking/dialogue over them (e.g., host talking over drum beat). This means:
- **Cannot get "pure" cue samples** from single episode
- Need **multiple samples** of same cue to extract common audio pattern
- Detection must work with **partially obscured cues**

### 3. Detection with Noise
Must detect cues even when talking is overlaid. Solutions:
- **Spectral subtraction** - Focus on frequency bands of the cue (e.g., drum beat)
- **Multiple cue samples** - Extract common features across samples
- **Feature-based matching** - Match spectral/rhythmic patterns, not raw audio

## Workflow

### Phase 1: Multi-Sample Cue Extraction

1. **User identifies ad cue type** (e.g., "drum beat intro")
2. **User provides 3-5 samples** of the same cue from different episodes
   - Each sample has talking/dialogue mixed in differently
   - System extracts common audio features across samples
3. **Feature extraction algorithm** identifies the consistent pattern (the cue)
4. **Store extracted feature fingerprint** (not raw audio)
5. **Repeat for ad end cue**

### Phase 2: Episode Download & Storage

1. **Download episode** immediately after RSS import
2. **Store in local media server** (`storage/episodes/{podcast_id}/{episode_id}.{ext}`)
3. **Track file metadata** (size, format, duration, checksum)
4. **Serve from local storage** (not original URL)
5. **Original URL becomes backup** if local file lost

### Phase 3: Automatic Ad Detection

1. **For each new episode**:
   - Download and store locally
   - **Extract spectral features** from audio
   - **Match against cue fingerprints** using feature similarity
   - Find start_cue timestamp(s) (with confidence scores)
   - Find end_cue timestamp(s)
   - **Create trimmed version** with ads removed
   - Store both original and trimmed
2. **Use trimmed version** for transcription and playback

## Data Model

```ruby
# AdCue model
class AdCue < ApplicationRecord
  belongs_to :podcast
  
  # Store feature fingerprints, not raw audio
  # fingerprint_data: JSON (spectral features, MFCCs, chroma features)
  # cue_type: enum [:start, :end]
  # sample_count: Integer (how many samples used to build fingerprint)
  # confidence_threshold: Float (0.0-1.0, default 0.7 for overlapping audio)
  
  # Metadata
  # duration_estimate: Float (seconds)
  # frequency_range: Array [min_hz, max_hz] for targeted matching
  # created_at, updated_at
end

# Episode model additions
class Episode < ApplicationRecord
  # Storage
  # local_audio_path: String (path to downloaded file)
  # local_audio_size: Integer (bytes)
  # local_audio_checksum: String (SHA256)
  # download_status: enum [:pending, :downloading, :stored, :failed]
  
  # Ad detection
  # ad_detection_status: enum [:pending, :processing, :detected, :none, :failed]
  # ad_segments: JSON array of {start: Float, end: Float, confidence: Float}
  # trimmed_audio_path: String
  # original_duration: Float
  # trimmed_duration: Float
end

# Podcast model additions
class Podcast < ApplicationRecord
  has_many :ad_cues
  
  # ad_cues_configured: Boolean
  # use_trimmed_audio: Boolean (enable/disable ad removal)
end
```

## Technology Stack

### Audio Processing & Storage
- **ffmpeg** - Download, convert, trim audio
- **pydub** - Python wrapper for audio manipulation
- **librosa** - Feature extraction (MFCCs, spectral features)

### Feature Extraction & Matching
- **librosa** - Extract spectral features (MFCCs, chroma, spectral contrast)
- **scipy** - Signal processing, cross-correlation with features
- **numpy** - Feature comparison and similarity scoring

### Multi-Sample Processing
1. **Extract features** from each sample (3-5 samples of same cue)
2. **Align samples** temporally
3. **Average/median spectral features** to get "clean" cue fingerprint
4. **Ignore outlier frequencies** (likely to be dialogue)
5. **Store compressed fingerprint** as JSON

### Detection Algorithm
1. **Extract features** from episode (sliding window)
2. **Compare with cue fingerprints** using cosine similarity
3. **Peak detection** for matches above threshold
4. **Pair start/end cues** to identify ad segments
5. **Trim audio** using ffmpeg

## API Design

### POST /api/podcasts/:id/ad_cues/samples
Upload multiple samples of the same cue

```json
{
  "cue_type": "start",
  "samples": [
    {
      "episode_id": 123,
      "start": 323.5,
      "end": 328.0,
      "audio_data": "base64..."
    },
    {
      "episode_id": 124,
      "start": 298.2,
      "end": 302.7,
      "audio_data": "base64..."
    }
  ]
}
```

Response:
```json
{
  "cue_id": 456,
  "fingerprint_quality": 0.87,
  "recommendations": "Good quality. Consider adding one more sample for better accuracy."
}
```

### GET /api/episodes/:id/audio_segment
Extract audio segment for cue creation

```
?start=323.5&end=328.0
Returns: WAV audio file
```

### POST /api/episodes/:id/download
Trigger episode download to local storage

## UI Components

### Cue Configuration Wizard

**Step 1: Select Cue Type**
- "Ad Start Cue" or "Ad End Cue"
- Description field (e.g., "Drum beat with 'Now back to the show'")

**Step 2: Provide Multiple Samples**
- Episode selector dropdown
- Waveform visualizer (wavesurfer.js) showing spectrogram
- Spectrogram view to see frequency patterns through talking
- Mark 3-5 samples of the same cue from different episodes
- Visual feedback on sample quality

**Step 3: Review Extracted Fingerprint**
- Show spectral features extracted
- Play "synthesized" version of detected cue (optional)
- Confidence score
- "Add more samples" or "Use this fingerprint"

**Step 4: Test Detection**
- Run on sample episode
- Show detected timestamps
- User confirms or adjusts threshold

### Episode Management
- Badge: "Downloaded Locally" / "Stream from Source"
- Badge: "Ads Detected" / "Ad-Free"
- Download button for episodes
- Show storage usage
- Original vs trimmed duration

## Implementation Phases

### Phase 1: Local Storage Infrastructure
- [x] Basic episode model
- [ ] Add download_status, local_audio_path fields
- [ ] API endpoint to trigger download
- [ ] Download job (similar to transcription job)
- [ ] Storage directory structure
- [ ] Serve episodes from local storage

### Phase 2: Multi-Sample Cue Extraction
- [ ] AdCue model and migration
- [ ] UI wizard for multi-sample collection
- [ ] Python service for feature extraction
- [ ] Algorithm to merge multiple samples into fingerprint
- [ ] Store fingerprint as JSON

### Phase 3: Ad Detection
- [ ] Python service for cue detection
- [ ] Job to process episodes
- [ ] Audio trimming with ffmpeg
- [ ] Store trimmed versions

### Phase 4: Integration & Polish
- [ ] Use trimmed audio for transcription
- [ ] Playback controls to show original vs trimmed
- [ ] Batch processing UI
- [ ] Quality metrics and tuning

## Algorithm Details

### Multi-Sample Feature Extraction

```python
# Pseudocode
def extract_common_features(audio_samples):
    features = []
    for sample in audio_samples:
        # Extract MFCCs (Mel-frequency cepstral coefficients)
        mfccs = librosa.feature.mfcc(sample, sr=22050, n_mfcc=13)
        # Extract spectral contrast
        contrast = librosa.feature.spectral_contrast(sample, sr=22050)
        # Extract chroma features (pitch content)
        chroma = librosa.feature.chroma_stft(sample, sr=22050)
        
        features.append({
            'mfccs': mfccs,
            'contrast': contrast,
            'chroma': chroma
        })
    
    # Compute median features (robust to outliers like talking)
    fingerprint = {
        'mfccs': np.median([f['mfccs'] for f in features], axis=0),
        'contrast': np.median([f['contrast'] for f in features], axis=0),
        'chroma': np.median([f['chroma'] for f in features], axis=0)
    }
    
    return fingerprint
```

### Detection with Features

```python
def detect_cue(episode_audio, cue_fingerprint):
    # Sliding window over episode
    window_size = cue_fingerprint['duration']
    matches = []
    
    for window in slide_windows(episode_audio, window_size):
        # Extract features from window
        window_features = extract_features(window)
        
        # Compare with fingerprint (cosine similarity)
        similarity = cosine_similarity(window_features, cue_fingerprint)
        
        if similarity > threshold:
            matches.append({
                'timestamp': window.start_time,
                'confidence': similarity
            })
    
    return matches
```

## Performance Considerations

- **Feature extraction is fast** (~1x realtime for MFCCs)
- **Detection scales linearly** with episode length
- **Can parallelize** across episodes
- **Cache episode features** to avoid re-processing

## Accuracy Improvements

1. **More samples = better fingerprint** (3-5 minimum, 10+ ideal)
2. **Consistent sample length** (±0.5 seconds)
3. **Focus on frequency bands** where cue is strongest
4. **Adjust confidence threshold** based on validation results
5. **Manual review interface** for false positives

## Privacy & Self-Hosting

- All audio stored locally
- No external API calls
- Feature extraction runs on your server
- Can disable ad removal per podcast
- Original files preserved

## Research References

- **Source Separation**: "Demucs" (Facebook Research) for isolating instruments
- **Audio Fingerprinting**: Shazam algorithm, chromaprint
- **Robust Audio Matching**: "Audio Content Analysis" by Alexander Lerch
- **Spectral Subtraction**: Classic DSP technique for noise reduction
