CSV Tool

A simple Bash-based CSV manipulation tool. It allows you to inspect, filter, sort, and process CSV files in various ways, without external dependencies beyond awk and standard Unix utilities.

Overview:

csv_tool.sh reads a CSV file into memory as a matrix and provides several operations to inspect, transform, and analyze CSV data.
Features include:
Remove rows by value (--remove)
Filter rows by condition (--where)
Sort by a column (--sort-by)
Validate CSV headers (--validate)
Select specific columns (--select)
Group and count field occurrences (--group-fields)
Compute numeric statistics (--stats)
Count distinct fields per column (--distinct-fields)

Usage:

./csv_tool.sh <csv_file> <option> [parameters...]
