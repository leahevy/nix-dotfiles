args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "ausweisapp";

  group = "security";
  input = "linux";

  module = {
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "AusweisApp";
          string = "Attempting to set another interceptor on QQuickImage property source - unsupported";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Connection error: QAbstractSocket::NetworkError \"Network unreachable\"";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Connection error: QAbstractSocket::NetworkError \"Host unreachable\"";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Connection could not be established after 5000 ms";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "NOT IMPLEMENTED: true";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Cannot select master file: UNSUPPORTED_INS";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Not a German EID card";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Cannot get EF\\.CardAccess";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "Update of the retry counter failed";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "NOT IMPLEMENTED: false";
          user = true;
          unitless = true;
        }
        {
          tag = "AusweisApp";
          string = "An error occurred: QNetworkReply::OperationCanceledError \"Operation canceled\"";
          user = true;
          unitless = true;
        }
      ];
    };

    system = config: {
      programs.ausweisapp = {
        enable = true;
        openFirewall = true;
      };
    };

    home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".cache/AusweisApp"
          ".config/AusweisApp"
        ];
      };
    };
  };
}
