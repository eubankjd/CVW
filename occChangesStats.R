# April 17, 2015
# Calculate occupational change statistics:
# 1) mean EE, UE, and pooled rate of occupational change over the whole period
# 2) correlation between rates of occupational change and the unemployment rate
# 3) quantile regression of unemployment rate on switching rate
# For more statistics, see summarizeData.R
# Precondition: processData.R has been run.
library(dplyr)
library(stats)
library(ggplot2)
library(xlsx)
library(quantreg)

setwd("~/workspace/CVW/R")

# Read unemployment data
haver <- read.xlsx("./Data/unrate.xlsx", sheetName = "data", 
                   startRow = 2, colIndex = 2:4)
# Change date to first of the month for merging
haver <- haver %>%
        mutate(month = format(date, "%m"),
               year = format(date, "%Y"),
               date = as.Date(paste(month, "/1/", year, sep=""), "%m/%d/%Y")) %>%
        select(-year, -month)

# 1996 Panel --------------------------------------------------------------
processed96 <- readRDS("./Data/processed96.RData")

# Calculate probability of switching using raw code
prSwitching <-  group_by(processed96, date) %>%
        summarize(prSwitchedOcc = weighted.mean(switchedOcc[EE | UE], wpfinwgt[EE | UE],
                                                na.rm = TRUE),
                  prSwitchedOccEE = weighted.mean(switchedOcc[EE], wpfinwgt[EE], na.rm = TRUE),
                  prSwitchedOccUE = weighted.mean(switchedOcc[UE], wpfinwgt[UE], na.rm = TRUE),
                  occObs = sum(wpfinwgt[EE | UE], na.rm = TRUE),
                  occEEObs = sum(wpfinwgt[EE], na.rm = TRUE),
                  occUEObs = sum(wpfinwgt[UE], na.rm = TRUE)) %>%
        mutate(panel = 1996)

# Remove 1996 data from environment
rm(processed96)

# 2001 Panel --------------------------------------------------------------
processed01 <- readRDS("./Data/processed01.RData")

# Calculate probability of switching, add to prSwitching
prSwitching <-  group_by(processed01, date) %>%
        summarize(prSwitchedOcc = weighted.mean(switchedOcc[EE | UE], wpfinwgt[EE | UE],
                                                na.rm = TRUE),
                  prSwitchedOccEE = weighted.mean(switchedOcc[EE], wpfinwgt[EE], na.rm = TRUE),
                  prSwitchedOccUE = weighted.mean(switchedOcc[UE], wpfinwgt[UE], na.rm = TRUE),
                  occObs = sum(wpfinwgt[EE | UE], na.rm = TRUE),
                  occEEObs = sum(wpfinwgt[EE], na.rm = TRUE),
                  occUEObs = sum(wpfinwgt[UE], na.rm = TRUE)) %>%
        mutate(panel = 2001) %>%
        bind_rows(prSwitching)

# Remove 2001 data from environment
rm(processed01)

# 2004 Panel --------------------------------------------------------------
processed04 <- readRDS("./Data/processed04.RData")

#Calculate probability of switching, add to prSwitching
prSwitching <-  group_by(processed04, date) %>%
        summarize(prSwitchedOcc = weighted.mean(switchedOcc[EE | UE], wpfinwgt[EE | UE],
                                                na.rm = TRUE),
                  prSwitchedOccEE = weighted.mean(switchedOcc[EE], wpfinwgt[EE], na.rm = TRUE),
                  prSwitchedOccUE = weighted.mean(switchedOcc[UE], wpfinwgt[UE], na.rm = TRUE),
                  occObs = sum(wpfinwgt[EE | UE], na.rm = TRUE),
                  occEEObs = sum(wpfinwgt[EE], na.rm = TRUE),
                  occUEObs = sum(wpfinwgt[UE], na.rm = TRUE)) %>%
        mutate(panel = 2004) %>%
        bind_rows(prSwitching)

# Remove 2004 data from environment
rm(processed04)

# 2008 Panel --------------------------------------------------------------
processed08 <- readRDS("./Data/processed08.RData")

#Calculate probability of switching, add to prSwitching
prSwitching <-  group_by(processed08, date) %>%
        summarize(prSwitchedOcc = weighted.mean(switchedOcc[EE | UE], wpfinwgt[EE | UE],
                                                na.rm = TRUE),
                  prSwitchedOccEE = weighted.mean(switchedOcc[EE], wpfinwgt[EE], na.rm = TRUE),
                  prSwitchedOccUE = weighted.mean(switchedOcc[UE], wpfinwgt[UE], na.rm = TRUE),
                  occObs = sum(wpfinwgt[EE | UE], na.rm = TRUE),
                  occEEObs = sum(wpfinwgt[EE], na.rm = TRUE),
                  occUEObs = sum(wpfinwgt[UE], na.rm = TRUE)) %>%
        mutate(panel = 2008) %>%
        bind_rows(prSwitching)

# Remove 2008 data from environment
rm(processed08)

# Statistics --------------------------------------------------------------

# Drop UE and pooled observations when the probability of UE is too low 
# (ad-hoc: less than 20th percentile for panel)
prSwitching <- prSwitching %>%
        group_by(panel) %>%
        mutate(cutoffUE = quantile(prSwitchedOccUE, probs = .2, na.rm = TRUE),
               prSwitchedOccUE = ifelse(prSwitchedOccUE < cutoffUE, 
                                        NA, prSwitchedOccUE),
               prSwitchedOcc = ifelse(prSwitchedOccUE < cutoffUE, 
                                        NA, prSwitchedOcc)) %>%
        select(-cutoffUE)
        

# Mean over whole period
with(prSwitching, weighted.mean(prSwitchedOcc, occObs, na.rm = TRUE))
with(prSwitching, weighted.mean(prSwitchedOccEE, occEEObs, na.rm = TRUE))
with(prSwitching, weighted.mean(prSwitchedOccUE, occUEObs, na.rm = TRUE))

# Correlation
prSwitchingAndUnemployment <- prSwitching %>%
        select(date, starts_with("prSwitched"), panel) %>%
        left_join(haver)
with(prSwitchingAndUnemployment, cor(prSwitchedOcc, unrateNSA, use = "complete.obs"))
with(prSwitchingAndUnemployment, cor(prSwitchedOccEE, unrateNSA, use = "complete.obs"))
with(prSwitchingAndUnemployment, cor(prSwitchedOccUE, unrateNSA, use = "complete.obs"))

# Quantile regressions ----------------------------------------------------

# Pooled
pooledReg <- rq(unrateNSA ~ prSwitchedOcc, tau = c(0.25, 0.50, 0.75), 
                data = prSwitchingAndUnemployment)

# EE
EEReg <- rq(unrateNSA ~ prSwitchedOccEE, tau = c(0.25, 0.50, 0.75), 
            data = prSwitchingAndUnemployment)

# UE
UEReg <- rq(unrateNSA ~ prSwitchedOccUE, tau = c(0.25, 0.50, 0.75), 
            data = prSwitchingAndUnemployment)

# All together
together <- rq(unrateNSA ~ prSwitchedOcc + prSwitchedOccEE + prSwitchedOccUE,
                 tau = c(0.25, 0.50, 0.75), data = prSwitchingAndUnemployment)