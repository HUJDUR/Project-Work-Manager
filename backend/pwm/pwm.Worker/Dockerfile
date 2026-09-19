# Build context is backend/pwm (not this directory) - pwm.Worker references
# pwm.Services and pwm.Common.Services as sibling projects, so the whole
# solution folder has to be visible to `dotnet restore`/`dotnet publish`.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY pwm.Worker/pwm.Worker.csproj pwm.Worker/
COPY pwm.Services/pwm.Services.csproj pwm.Services/
COPY pwm.Common.Services/pwm.Common.Services.csproj pwm.Common.Services/
COPY pwm.Model/pwm.Model.csproj pwm.Model/
RUN dotnet restore pwm.Worker/pwm.Worker.csproj

COPY . .
RUN dotnet publish pwm.Worker/pwm.Worker.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENTRYPOINT ["dotnet", "pwm.Worker.dll"]
