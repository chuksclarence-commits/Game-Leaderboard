# Comprehensive Leaderboard Smart Contract

## Overview

This is a comprehensive leaderboard smart contract built for the Stacks blockchain. It enables the creation and management of multiple competitive leaderboards with scoring systems, reward pools, and administrative controls.

## Features

- **Multiple Leaderboards**: Create and manage unlimited leaderboards
- **Scoring System**: Submit and track participant scores with ranking
- **Reward Distribution**: STX reward pools with automatic distribution
- **Admin Controls**: Multi-level administrative permissions
- **Time-based Competitions**: Optional end times for leaderboards
- **Participant Statistics**: Track individual performance across leaderboards
- **Input Validation**: Comprehensive validation for all operations
- **Security**: Owner-only functions and admin authorization

## Contract Architecture

### Constants

- `contract-owner`: The deployer of the contract
- `max-leaderboard-entries`: Maximum of 1000 participants per leaderboard
- Error codes ranging from u100 to u110 for different failure scenarios

### Data Storage

#### Global Variables
- `contract-active`: Global on/off switch for the contract
- `next-leaderboard-id`: Auto-incrementing ID counter
- `total-leaderboards`: Total number of created leaderboards

#### Data Maps
- `leaderboards`: Leaderboard metadata and configuration
- `leaderboard-scores`: Individual participant scores and statistics
- `leaderboard-rankings`: Optimized ranking data for queries
- `admins`: Administrative permissions
- `participant-stats`: Cross-leaderboard participant statistics
- `reward-claims`: Reward distribution tracking

## Public Functions

### Administrative Functions

#### `add-admin(new-admin: principal)`
Adds a new administrator to the contract.
- **Access**: Contract owner only
- **Parameters**: Principal address of the new admin
- **Returns**: Success confirmation

#### `remove-admin(admin-to-remove: principal)`
Removes an administrator from the contract.
- **Access**: Contract owner only
- **Parameters**: Principal address of the admin to remove
- **Returns**: Success confirmation

#### `set-contract-status(active: bool)`
Toggles the global contract active status.
- **Access**: Contract owner only
- **Parameters**: Boolean active status
- **Returns**: Success confirmation

### Leaderboard Management

#### `create-leaderboard(name, description, max-participants, end-time)`
Creates a new leaderboard.
- **Access**: Any user (when contract is active)
- **Parameters**:
  - `name`: String (max 64 characters)
  - `description`: String (max 256 characters)
  - `max-participants`: Maximum number of participants (1-1000)
  - `end-time`: Optional end timestamp
- **Returns**: New leaderboard ID

#### `update-leaderboard(leaderboard-id, name, description, active)`
Updates leaderboard settings.
- **Access**: Leaderboard owner or admin
- **Parameters**:
  - `leaderboard-id`: Target leaderboard ID
  - `name`: Updated name
  - `description`: Updated description
  - `active`: Updated active status
- **Returns**: Success confirmation

#### `add-reward-pool(leaderboard-id: uint, amount: uint)`
Adds STX to the leaderboard reward pool.
- **Access**: Any user
- **Parameters**:
  - `leaderboard-id`: Target leaderboard ID
  - `amount`: STX amount to add (in microSTX)
- **Returns**: Success confirmation
- **Note**: Transfers STX from sender to contract

### Scoring Functions

#### `submit-score(leaderboard-id: uint, score: uint)`
Submits a score to a leaderboard.
- **Access**: Any user
- **Parameters**:
  - `leaderboard-id`: Target leaderboard ID
  - `score`: Score value (must be > 0)
- **Returns**: Success confirmation
- **Behavior**: Only updates if new score is higher than existing score

### Reward Functions

#### `claim-reward(leaderboard-id: uint)`
Claims rewards from a completed leaderboard.
- **Access**: Leaderboard participants
- **Parameters**: `leaderboard-id`: Target leaderboard ID
- **Returns**: Reward amount claimed
- **Distribution**:
  - 1st place: 50% of reward pool
  - 2nd place: 30% of reward pool
  - 3rd place: 20% of reward pool

## Read-Only Functions

### Query Functions

#### `get-leaderboard(leaderboard-id: uint)`
Retrieves complete leaderboard information.

#### `get-participant-score(leaderboard-id: uint, participant: principal)`
Gets a participant's score and statistics for a specific leaderboard.

#### `get-participant-stats(participant: principal)`
Retrieves cross-leaderboard statistics for a participant.

#### `get-ranking-at-position(leaderboard-id: uint, rank: uint)`
Gets the participant at a specific rank position.

#### `is-user-admin(user: principal)`
Checks if a user has administrative privileges.

#### `get-contract-status()`
Returns global contract status and statistics.

#### `get-reward-claim-status(leaderboard-id: uint, participant: principal)`
Checks if a participant has claimed their reward.

#### `calculate-potential-reward(leaderboard-id: uint, participant: principal)`
Calculates potential reward for a participant based on current ranking.

#### `is-leaderboard-active(leaderboard-id: uint)`
Checks if a leaderboard is active and not expired.

## Usage Examples

### Creating a Leaderboard

```clarity
(contract-call? .leaderboard create-leaderboard 
    "Gaming Tournament" 
    "Weekly gaming competition with STX rewards" 
    u100 
    (some u1640995200)) ;; Optional end time
```

### Submitting a Score

```clarity
(contract-call? .leaderboard submit-score u1 u1500)
```

### Adding Rewards

```clarity
(contract-call? .leaderboard add-reward-pool u1 u1000000) ;; 1 STX
```

### Claiming Rewards

```clarity
(contract-call? .leaderboard claim-reward u1)
```

## Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Resource not found
- `u102`: Resource already exists
- `u103`: Invalid score value
- `u104`: Leaderboard not found
- `u105`: Insufficient funds for operation
- `u106`: Invalid participant (e.g., participant limit exceeded)
- `u107`: Leaderboard inactive or expired
- `u108`: Invalid parameters provided
- `u109`: Reward not available or already claimed
- `u110`: Invalid principal address

## Security Features

### Input Validation
- All string inputs are length-validated
- Principal addresses are verified as valid
- Numeric parameters are range-checked
- Leaderboard IDs are validated against existing records

### Access Controls
- Contract owner has supreme administrative rights
- Multi-level admin system with granular permissions
- Leaderboard owners can manage their own leaderboards
- Participants can only modify their own scores

### Time-based Security
- Optional leaderboard end times prevent late submissions
- Reward claims are only available after leaderboard completion
- Timestamps are validated for consistency

## Deployment Considerations

1. **Initial Setup**: The deploying address becomes the contract owner
2. **STX Requirements**: Ensure sufficient STX for reward pools
3. **Admin Management**: Add trusted admins after deployment
4. **Testing**: Test all functions thoroughly before mainnet deployment

## Integration Guidelines

### For Frontend Applications
- Use read-only functions for displaying leaderboard data
- Implement proper error handling for all contract calls
- Cache frequently accessed data to reduce RPC calls
- Implement real-time updates for score submissions

### for Game Integration
- Submit scores immediately after game completion
- Validate scores client-side before submission
- Handle network failures gracefully
- Implement retry mechanisms for failed submissions