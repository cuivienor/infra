# Garmin & Strava Data Reference

Comprehensive reference of all available data fields from Garmin Connect and Strava APIs.

## Overview

| Platform | API Type | Strength Training Detail | Rate Limits |
|----------|----------|-------------------------|-------------|
| **Garmin** | Unofficial (garminconnect/garth) | ✅ Full (exercises, sets, reps, weights) | None documented |
| **Strava** | Official OAuth2 | ❌ None (time-based only) | 200/15min, 2000/day |

**Key Insight**: Garmin is the source of truth for strength training data. Strava only stores aggregate metrics (duration, calories).

---

## Garmin Connect

### Activity Types

| Category | Types |
|----------|-------|
| **Running** | `running`, `trail_running`, `treadmill_running` |
| **Cycling** | `cycling`, `indoor_cycling`, `mountain_biking`, `road_cycling`, `gravel_cycling`, `e_biking` |
| **Swimming** | `swimming`, `open_water_swimming`, `lap_swimming` |
| **Walking** | `walking`, `hiking`, `speed_walking` |
| **Gym** | `strength_training`, `elliptical`, `fitness_equipment` |
| **Winter** | `cross_country_skiing`, `alpine_skiing`, `snowboarding` |
| **Water** | `rowing`, `paddling`, `surfing`, `kiteboarding`, `windsurfing` |
| **Other** | `golf`, `multi_sport` |

### Activity Data

#### Common Fields (All Activity Types)

```python
# Retrieval
activity = garmin.get_activity(activity_id)

# Core identifiers
activity_id: int
activity_name: str
activity_type: str  # e.g., "strength_training", "running"
start_time_local: datetime
start_time_gmt: datetime

# Duration
duration: float  # seconds
moving_duration: float  # seconds
elapsed_duration: float  # seconds

# Distance (when applicable)
distance: float  # meters

# Elevation
elevation_gain: float  # meters
elevation_loss: float  # meters
max_elevation: float  # meters
min_elevation: float  # meters

# Speed
average_speed: float  # m/s
max_speed: float  # m/s

# Heart Rate
average_hr: int  # bpm
max_hr: int  # bpm
min_hr: int  # bpm

# Calories
calories: float  # kcal
bmr_calories: float  # kcal

# Location
start_latitude: float
start_longitude: float
end_latitude: float
end_longitude: float
```

#### Strength Training

```python
# Retrieval
exercise_sets = garmin.get_activity_exercise_sets(activity_id)

# Structure
{
    "exerciseSets": [
        {
            "setType": "ACTIVE",  # or "REST"
            "exercises": [
                {
                    "name": "BARBELL_BENCH_PRESS",
                    "category": "BENCH_PRESS"
                }
            ],
            "repetitionCount": 10,
            "weight": 60000,  # grams (60kg)
            "duration": 45.0,  # seconds
            "startTime": "2024-01-15T10:30:00.000"
        }
    ]
}

# Exercise names are Garmin's internal identifiers:
# - BARBELL_BENCH_PRESS, DUMBBELL_BENCH_PRESS
# - BARBELL_SQUAT, GOBLET_SQUAT
# - PULL_UP, LAT_PULLDOWN
# - ELBOW_TO_FOOT_LUNGE, ANKLE_DORSIFLEXION_WITH_BAND
```

#### Running Metrics

```python
# Running dynamics (device-dependent)
average_run_cadence: int  # steps/min
max_run_cadence: int
ground_contact_time: float  # milliseconds
stride_length: float  # meters
vertical_oscillation: float  # millimeters
vertical_ratio: float  # percentage
```

#### Cycling Metrics

```python
# Power (requires power meter)
average_power: int  # watts
max_power: int
normalized_power: int
total_work: float  # kilojoules

# Cycling dynamics (device-dependent)
left_right_balance: float  # percentage
left_torque_effectiveness: float
right_torque_effectiveness: float
left_pedal_smoothness: float
right_pedal_smoothness: float
```

#### Swimming Metrics

```python
average_swim_cadence: int  # strokes/min
average_swolf: int  # strokes per length
avg_stroke_distance: float  # meters/stroke
```

### Splits & Laps

```python
# Retrieval
splits = garmin.get_activity_splits(activity_id)

# Each split contains:
{
    "distance": 1000,  # meters
    "duration": 300,  # seconds
    "average_hr": 145,
    "max_hr": 160,
    "elevation_gain": 15,
    "elevation_loss": 10,
    "average_speed": 3.33,  # m/s
    "split_type": "kilometer"  # or "mile", "lap"
}
```

### HR Zones

```python
# Retrieval
hr_zones = garmin.get_activity_hr_in_timezones(activity_id)

# Structure
[
    {"zone": 1, "secsInZone": 300, "zoneLowBoundary": 0},
    {"zone": 2, "secsInZone": 600, "zoneLowBoundary": 104},
    {"zone": 3, "secsInZone": 900, "zoneLowBoundary": 124},
    {"zone": 4, "secsInZone": 450, "zoneLowBoundary": 143},
    {"zone": 5, "secsInZone": 150, "zoneLowBoundary": 162}
]
```

### Training Metrics

```python
# Available in activity details
training_effect: float  # 0.0 - 5.0
anaerobic_training_effect: float  # 0.0 - 5.0
activity_training_load: int  # training load points
body_battery_change: int  # drain/recharge

# Stamina
begin_potential_stamina: float  # percentage
end_potential_stamina: float
min_available_stamina: float

# Intensity minutes
moderate_intensity_minutes: int
vigorous_intensity_minutes: int
```

### File Downloads

```python
# Download activity files
garmin.download_activity(activity_id, output_dir, file_format="fit")

# Formats available:
# - "fit" - Full native data (recommended)
# - "gpx" - GPS track (XML)
# - "tcx" - Training Center XML (includes HR)
# - "csv" - Summary only
```

---

### Health & Wellness Data

#### Body Composition

```python
# Retrieval
body_comp = garmin.get_body_composition(start_date, end_date)

# Fields
weight: float  # kg
bmi: float
body_fat_percentage: float
body_water_percentage: float
bone_mass: float  # kg
muscle_mass: float  # kg
visceral_fat_rating: int
metabolic_age: int
physique_rating: int
```

#### Heart Rate

```python
# Daily HR
hr_data = garmin.get_heart_rates(date)
{
    "restingHeartRate": 62,
    "maxHeartRate": 165,
    "minHeartRate": 48,
    "heartRateValues": [
        {"seconds": 0, "heartRate": 58, "timestampGMT": 1705272000000}
    ]
}

# HRV
hrv = garmin.get_hrv_data(date)
{
    "hrvSummary": {
        "weeklyAvg": 52,
        "lastNightAvg": 55,
        "status": "GOOD"
    }
}
```

#### Sleep

```python
sleep = garmin.get_sleep_data(date)
{
    "sleepTimeSeconds": 28800,
    "deepSleepSeconds": 7200,
    "lightSleepSeconds": 14400,
    "remSleepSeconds": 7200,
    "awakeSleepSeconds": 600,
    "sleepScore": 85,
    "sleepQuality": "GOOD"
}
```

#### Stress & Body Battery

```python
# Stress
stress = garmin.get_all_day_stress(date)
{
    "avgStressLevel": 35,
    "maxStressLevel": 75,
    "overallStressScore": 65
}

# Body Battery
battery = garmin.get_body_battery(start_date, end_date)
{
    "charged": 85,
    "drained": 15,
    "highestValue": 92,
    "lowestValue": 55
}
```

#### Training Status

```python
# Training status
status = garmin.get_training_status(date)
{
    "trainingStatus": "Productive",
    "load": 375,
    "performance": 85,
    "recovery": 72
}

# Training readiness
readiness = garmin.get_training_readiness(date)
{
    "score": 72,
    "performanceCondition": "Good",
    "recoveryTime": 12
}

# VO2 Max & Fitness Age
metrics = garmin.get_max_metrics(date)
{
    "vo2MaxRunning": 52,
    "vo2MaxCycling": 45,
    "fitnessAge": 28
}

# Race predictions
predictions = garmin.get_race_predictions(start_date, end_date, "running")
{
    "5k": {"time": "00:22:30", "pace": "04:30/km"},
    "10k": {"time": "00:46:45", "pace": "04:41/km"},
    "halfMarathon": {"time": "01:43:15", "pace": "04:55/km"},
    "marathon": {"time": "03:32:30", "pace": "05:01/km"}
}
```

#### Daily Metrics

```python
# Steps
steps = garmin.get_steps_data(date)
{
    "totalSteps": 10500,
    "dailyStepGoal": 10000,
    "distance": 7.5  # km
}

# SpO2
spo2 = garmin.get_spo2_data(date)
{
    "averageSpO2": 97,
    "lowestSpO2": 94
}

# Respiration
resp = garmin.get_respiration_data(date)
{
    "avgRespirationValue": 14.5
}

# Hydration
hydration = garmin.get_hydration_data(date)
{
    "valueInML": 2500,
    "goalInML": 3000
}

# Intensity Minutes
intensity = garmin.get_intensity_minutes_data(date)
{
    "weeklyGoal": 150,
    "weeklyValue": 120,
    "moderateValue": 30,
    "vigorousValue": 20
}
```

---

## Strava

### Activity Types (44+ supported)

| Category | Types |
|----------|-------|
| **Running** | `Run`, `TrailRun`, `VirtualRun`, `Walk`, `Hike` |
| **Cycling** | `Ride`, `MountainBikeRide`, `GravelRide`, `EBikeRide`, `VirtualRide`, `Handcycle` |
| **Swimming** | `Swim` |
| **Winter** | `AlpineSki`, `BackcountrySki`, `NordicSki`, `Snowboard`, `Snowshoe`, `IceSkate` |
| **Water** | `Kayaking`, `Kitesurf`, `Rowing`, `Sail`, `StandUpPaddling`, `Surfing` |
| **Fitness** | `WeightTraining`, `Workout`, `Elliptical`, `StairStepper`, `HIIT`, `Crossfit`, `Pilates`, `Yoga` |
| **Racket** | `Tennis`, `Badminton`, `TableTennis`, `Pickleball`, `Racquetball`, `Squash` |
| **Other** | `Golf`, `RockClimbing`, `Skateboard`, `InlineSkate`, `Soccer` |

### Activity Data

#### Common Fields

```python
# Retrieval
activity = strava.get_activity(activity_id)

# Core
id: int
name: str
sport_type: str  # e.g., "Run", "WeightTraining"
start_date: datetime
start_date_local: datetime
timezone: str

# Duration
elapsed_time: int  # seconds
moving_time: int  # seconds

# Distance
distance: float  # meters

# Elevation
total_elevation_gain: float  # meters
elev_high: float
elev_low: float

# Speed
average_speed: float  # m/s
max_speed: float

# Heart Rate
average_heartrate: float  # bpm
max_heartrate: float
has_heartrate: bool

# Calories
calories: float
kilojoules: float  # cycling

# Location
start_latlng: [float, float]
end_latlng: [float, float]

# Social
kudos_count: int
comment_count: int
achievement_count: int
pr_count: int

# Gear
gear_id: str
gear: {id, name, primary, distance}
device_name: str

# Map
map: {id, polyline, summary_polyline}

# Flags
trainer: bool  # indoor
commute: bool
manual: bool
private: bool
```

#### Running/Cycling Splits

```python
# Included in activity detail
splits_metric: [  # per kilometer
    {
        "distance": 1000,
        "elapsed_time": 300,
        "moving_time": 295,
        "elevation_difference": 15,
        "average_speed": 3.33,
        "pace_zone": 3
    }
]

splits_standard: [...]  # per mile
```

#### Laps

```python
# Included in activity detail
laps: [
    {
        "lap_index": 1,
        "distance": 1000,
        "elapsed_time": 300,
        "moving_time": 295,
        "total_elevation_gain": 15,
        "average_speed": 3.33,
        "max_speed": 4.5,
        "average_cadence": 85,
        "average_heartrate": 145,
        "max_heartrate": 160
    }
]
```

#### Segment Efforts

```python
# Retrieval (include_all_efforts=true)
activity = strava.get_activity(activity_id, include_all_efforts=True)

segment_efforts: [
    {
        "id": 12345,
        "name": "Tunnel Rd.",
        "distance": 9434.8,
        "elapsed_time": 1800,
        "moving_time": 1750,
        "start_index": 211,
        "end_index": 2246,
        "average_cadence": 78.6,
        "average_watts": 237.6,
        "kom_rank": null,
        "pr_rank": 1,
        "segment": {
            "id": 673683,
            "distance": 9220.7,
            "average_grade": 4.2,
            "maximum_grade": 25.8,
            "climb_category": 3
        },
        "achievements": [...]
    }
]
```

#### Power Data (Cycling)

```python
# Requires power meter
average_watts: int
weighted_average_watts: int  # Normalized Power
max_watts: int
kilojoules: float
device_watts: bool  # true if from device
```

### Streams (Time-Series Data)

```python
# Retrieval
streams = strava.get_activity_streams(
    activity_id,
    keys=["time", "heartrate", "cadence", "altitude", "latlng", "watts", "velocity_smooth", "grade_smooth", "temp", "moving", "distance"]
)

# 11 stream types available:
time: [int]  # seconds from start
latlng: [[float, float]]  # [lat, lng] pairs
distance: [float]  # cumulative meters
altitude: [float]  # meters
velocity_smooth: [float]  # m/s
heartrate: [int]  # bpm
cadence: [int]  # rpm/spm
watts: [int]  # power
temp: [int]  # degrees C
moving: [bool]
grade_smooth: [float]  # percent grade

# Response structure
{
    "heartrate": {
        "data": [120, 125, 130, ...],
        "series_type": "distance",
        "original_size": 3600,
        "resolution": "high"
    }
}
```

### Zones

```python
# HR Zones
zones = strava.get_activity_zones(activity_id)
{
    "heart_rate": {
        "distribution_buckets": [
            {"min": 0, "max": 115, "time": 300},
            {"min": 115, "max": 152, "time": 600},
            {"min": 152, "max": 171, "time": 900},
            {"min": 171, "max": 190, "time": 450},
            {"min": 190, "max": -1, "time": 150}
        ]
    },
    "power": {...}  # if available
}
```

### Photos

```python
# Included in activity detail
photos: {
    "primary": {
        "unique_id": "...",
        "urls": {
            "100": "https://...",
            "600": "https://..."
        }
    },
    "count": 2
}
total_photo_count: int
```

### Strength Training Limitations

**⚠️ CRITICAL**: Strava does NOT provide exercise-level detail for strength workouts.

**Available:**
- `sport_type`: "WeightTraining" or "Workout"
- `name`, `description`
- `elapsed_time`, `moving_time`
- `calories`
- `trainer` (indoor)
- `workout_type` (integer enum)
- Time-based splits if device reports

**NOT Available:**
- ❌ Individual exercises
- ❌ Sets/reps per exercise
- ❌ Weight lifted
- ❌ Rest periods
- ❌ Exercise order

### Rate Limits

```
Overall:
  - 200 requests per 15 minutes
  - 2,000 requests per day

Read-only (GET):
  - 100 requests per 15 minutes
  - 1,000 requests per day

Response Headers:
  X-RateLimit-Limit: 200,2000
  X-RateLimit-Usage: 15,150
```

### Required Scopes

| Scope | Access |
|-------|--------|
| `activity:read` | Public and follower activities |
| `activity:read_all` | All activities including private |
| `activity:write` | Create/update activities |

---

## Data Sync Considerations

### What Can Be Synced Garmin → Strava

| Data | Syncable | Notes |
|------|----------|-------|
| Activity name | ✅ | Direct mapping |
| Description | ✅ | Direct mapping |
| Sport type | ⚠️ | Requires type mapping |
| Start time | ✅ | Auto-synced by Garmin |
| Duration | ✅ | Auto-synced |
| Distance | ✅ | Auto-synced |
| HR data | ✅ | Auto-synced |
| GPS track | ✅ | Auto-synced via FIT upload |
| Strength exercises | ❌ | Strava doesn't support |
| Sets/reps/weights | ❌ | Strava doesn't support |

### Matching Activities

Activities can be matched by:
1. **Start time** (within tolerance, accounting for timezone)
2. **Duration** (within tolerance)
3. **Distance** (for cardio activities)
4. **Activity type** mapping

### Use Cases

1. **Name Sync**: Update Strava activity names from Garmin
2. **Description Enrichment**: Add Garmin strength details to Strava description
3. **Data Export**: Export all data to local DB (DuckDB)
4. **Backup**: Archive activity files (FIT format)
