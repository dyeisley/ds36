
# Copy the driver code to the current directory.
cp ../drivers/ds35xdriver.cs .

# Make sure dotnet is installed.
dnf install dotnet-sdk-7.0

# Build the code.
dotnet build

# Run the client with the config file created after running ../CreateConfigFile.pl
dotnet run --config_file=../DriverConfig.txt

