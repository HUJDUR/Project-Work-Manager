# Build context is backend/pwm (not this directory) - pwm.WebAPI references
# pwm.Services, and transitively pwm.Common.Services/pwm.Model, as sibling
# projects, so the whole solution folder has to be visible to `dotnet
# restore`/`dotnet publish`.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY pwm.WebAPI/pwm.WebAPI.csproj pwm.WebAPI/
COPY pwm.Services/pwm.Services.csproj pwm.Services/
COPY pwm.Common.Services/pwm.Common.Services.csproj pwm.Common.Services/
COPY pwm.Model/pwm.Model.csproj pwm.Model/
RUN dotnet restore pwm.WebAPI/pwm.WebAPI.csproj

COPY . .
RUN dotnet publish pwm.WebAPI/pwm.WebAPI.csproj -c Release -o /app --no-restore

# The ASP.NET Core runtime image, not the bare `runtime` one pwm.Worker uses -
# this is a web app and needs the Kestrel/hosting bits that image doesn't carry.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENTRYPOINT ["dotnet", "pwm.WebAPI.dll"]
