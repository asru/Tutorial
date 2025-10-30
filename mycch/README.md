# MYCCH - Modified / Enhanced version of Collectibles Clearing House

Enhanced version with duplicate consolidation, robust cursor handling, and fast-mode optimization.

## Features
- Smart duplicate detection and stack consolidation
- Handles full bags gracefully (returns to housing instead of erroring)
- Fast mode: 700ms waits optimized for low-lag zones
- Dynamic list re-sorting support
- Remote character control via DanNet

## Installation
Copy the `mycch/` folder to your `MacroQuest/lua/` directory.

## Usage
In-game: `/lua run mycch`

The drop down list will show all characters currently connected via DanNet, and have them perform the selected action.

- **Store All Collectibles** - Store all collectibles in the selected character's inventory in your house
- **Retrieve All Collectibles** - Retrieve all collectibles from your house into the selected character's inventory
- **Collect and Return** - Grab all collectibles from your house, collect them if necessary, then return them to housing storage
- **Collect in Inventory** - Collect all collectibles in the selected character's inventory

## Changes from Upstream CCH
See commit history for detailed improvements.