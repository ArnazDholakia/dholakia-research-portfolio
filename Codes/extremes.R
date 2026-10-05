library(ncdf4)
library(trend)

# ---------------------------------------------------------------
# Settings
# ---------------------------------------------------------------
base_dir  <- "C:/thesis/28112024_LEO_ExtremeIndices-Germany/"
years     <- 1941:2022
n_years   <- length(years)
summer    <- c(6, 7, 8)   # JJA
i_lon     <- 41           # grid cell index (lon)
i_lat     <- 5            # grid cell index (lat)
alpha     <- 0.05

# ---------------------------------------------------------------
# Functions
# ---------------------------------------------------------------

# Read one index from a NetCDF file and return the series for ONE grid cell
load_cell_series <- function(file, varname, i_lon, i_lat) {
  nc <- nc_open(file.path(base_dir, file))
  on.exit(nc_close(nc))
  
  arr  <- ncvar_get(nc, varname)
  fill <- ncatt_get(nc, varname, "missing_value")$value
  unit <- ncatt_get(nc, varname, "units")$value
  lon  <- ncvar_get(nc, "longitude")
  lat  <- ncvar_get(nc, "latitude")
  
  arr[arr == fill] <- NA
  
  cat(varname, "| dims:", paste(dim(arr), collapse = " x "),
      "| cell lon =", lon[i_lon], "lat =", lat[i_lat], "\n")
  
  # Assumes dimension order lon x lat x time. Check the printed dims!
  series <- arr[i_lon, i_lat, ]
  list(series = series, units = unit)
}

# Monthly series (82*12 values) -> yearly summary over chosen months
monthly_to_yearly <- function(x, months = 1:12, fun = mean) {
  m <- matrix(x, nrow = n_years, byrow = TRUE)   # rows = years, cols = months
  apply(m[, months, drop = FALSE], 1, fun, na.rm = TRUE)
}

# Plot a yearly series, post-2000 highlighted, and run Mann-Kendall
analyse_series <- function(y, title, ylab) {
  plot(years, y, pch = 19, main = title, xlab = "Year", ylab = ylab)
  post <- years >= 2000
  points(years[post], y[post], pch = 19, col = "red")
  legend("topleft", legend = "Post 2000", col = "red", pch = 19, bty = "n")
  
  mk <- mk.test(na.omit(y))
  cat(title, "- Mann-Kendall p-value:", signif(mk$p.value, 4), "\n")
  invisible(mk)
}

# Kendall's tau between two series, with a readable verdict
kendall_report <- function(x, y, label) {
  res <- cor.test(x, y, method = "kendall")
  cat("\n---", label, "---\n")
  cat("tau =", round(res$estimate, 3), "| p =", signif(res$p.value, 4), "\n")
  if (res$p.value < alpha) {
    cat("Statistically significant at the", (1 - alpha) * 100, "% level.\n")
  } else {
    cat("NOT statistically significant at the", (1 - alpha) * 100, "% level.\n")
  }
  invisible(res)
}

# ---------------------------------------------------------------
# Load data
# ---------------------------------------------------------------
txn <- load_cell_series("txnETCCDI_mon_ERA5_Germany_194101-202212.nc",    "txnETCCDI",    i_lon, i_lat)
rx5 <- load_cell_series("rx5dayETCCDI_mon_ERA5_Germany_194101-202212.nc", "rx5dayETCCDI", i_lon, i_lat)
txx <- load_cell_series("txxETCCDI_mon_ERA5_Germany_194101-202212.nc",    "txxETCCDI",    i_lon, i_lat)
r10 <- load_cell_series("r10mmETCCDI_yr_ERA5_Germany_1941-2022.nc",       "r10mmETCCDI",  i_lon, i_lat)

# ---------------------------------------------------------------
# Yearly series
# ---------------------------------------------------------------
txn_JJA <- monthly_to_yearly(txn$series, summer)
txn_all <- monthly_to_yearly(txn$series)
rx5_JJA <- monthly_to_yearly(rx5$series, summer)
rx5_all <- monthly_to_yearly(rx5$series)
txx_JJA <- monthly_to_yearly(txx$series, summer)
txx_all <- monthly_to_yearly(txx$series)

# R10mm is already ANNUAL: use as is (no monthly reshaping!)
r10_yr  <- r10$series
stopifnot(length(r10_yr) == n_years)

# ---------------------------------------------------------------
# Trends (Mann-Kendall) + plots
# ---------------------------------------------------------------
par(mfrow = c(2, 2))
analyse_series(txn_JJA, "TXn, JJA mean (Germany)",   paste0("Temperature (", txn$units, ")"))
analyse_series(rx5_JJA, "Rx5day, JJA mean (Germany)", paste0("Precipitation (", rx5$units, ")"))
analyse_series(txx_JJA, "TXx, JJA mean (Germany)",   paste0("Temperature (", txx$units, ")"))
analyse_series(r10_yr,  "R10mm, annual (Germany)",   "Days per year")
par(mfrow = c(1, 1))

# Optional: all-month means
# analyse_series(txn_all, "TXn, all-month mean", "Temperature")

# ---------------------------------------------------------------
# Kendall's tau correlations
# ---------------------------------------------------------------
kendall_report(txn_JJA, rx5_JJA, "TXn (JJA) vs Rx5day (JJA)")
kendall_report(txx_JJA, rx5_JJA, "TXx (JJA) vs Rx5day (JJA)")
kendall_report(txx_JJA, r10_yr,  "TXx (JJA) vs R10mm (annual)")