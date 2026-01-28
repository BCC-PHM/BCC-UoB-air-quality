
library(readxl)
library(tidyverse)
library(sf)
library(INLA)
library("spdep")
library("openxlsx")

########################################################################################################################
#asthma data
stroke_df = read_excel("~/R projects/PHM/BCC_UOB_air_quality/data/air-quality-related-admissions-by-lsoa-2025.xlsx", 
                    sheet = "Stroke")
#lsoa shape
lsoa21_map = read_sf("data/boundaries-lsoa-2021-birmingham/boundaries-lsoa-2021-birmingham.shp")

# Create a stable numeric ID for each LSOA (in current data order)
lsoa21_map$new_id = 1:nrow(lsoa21_map)


#lsoa population 
lsoapopulation <- read_excel("~/R projects/PHM/BCC_UOB_air_quality/data/lsoapopulation.xlsx", 
                             sheet = "Mid-2022 LSOA 2021", skip = 3)

########################################################################################################################
#join lsoa pop to lsoa21map

bham_lsoa_pop =lsoa21_map%>% 
  left_join(lsoapopulation %>% filter(`LAD 2021 Name` == "Birmingham"), by = c("LSOA21CD" = "LSOA 2021 Code")) %>% 
  select(LSOA21CD, LSOA21NM,Total,new_id)




#process stroke
stroke_processed = stroke_df %>% 
  filter(LSOA_CODE %in% lsoa21_map$LSOA21CD) %>% 
  right_join(bham_lsoa_pop, by = c("LSOA_CODE"="LSOA21CD")) %>% 
  mutate(IHD_Admissions = ifelse(is.na(IHD_Admissions),0,IHD_Admissions))



##################################################
# Define spatial neighbourhood structure (LSOA adjacency)
##################################################


# Reproject to British National Grid (EPSG:27700)
# Using metres avoids angular distortion and improves geometric operations
lsoa21_map = st_transform(lsoa21_map, 27700)

# Ensure geometries are valid (fix if necessary)
lsoa21_map = st_make_valid(lsoa21_map)
which(!st_is_valid(lsoa21_map))

# Create adjacency list
mcnty_nb = poly2nb(lsoa21_map, row.names = lsoa21_map$new_id, queen = TRUE)


# Convert neighbour list to an INLA adjacency graph

# Convert the nb object into an adjacency file required by R-INLA
nb2INLA("lsoa.adj", mcnty_nb)

# Read the adjacency file back into R as an INLA graph object
g = inla.read.graph("lsoa.adj")

# ----------------------------------------------------------
# Fit a Bayesian spatial Poisson model (BYM2) using R-INLA
# ----------------------------------------------------------

# 1) Specify the model formula
# - count: observed number of cases in each LSOA
# - 1: intercept-only baseline risk
# - f(new_id, model="bym2"): BYM2 spatial random effect indexed by LSOA ID
# - graph=g: neighbourhood structure used by the spatial component

formula = IHD_Admissions ~ 1 + f(new_id,
                                 model = "bym2",
                                 graph = g,
                                 hyper = list(
                                   # PC prior for precision (overall variability / smoothing strength)
                                   prec = list(prior = "pc.prec", param = c(1, 0.01)),
                                   # PC prior for phi (mix between spatially structured vs unstructured variation)
                                   phi = list(prior = "pc", param = c(0.5, 0.5))
                                 ))

# 2) Fit the model using a Poisson likelihood
# - offset = log(pop): adjusts for population/denominator so we model risk/rate
# - control.predictor: computes fitted values for mapping and summaries

fitmod = inla(
  formula,
  data = stroke_processed,
  family = "poisson",
  offset = log(Total),
  control.predictor = list(compute = TRUE),
  verbose = TRUE
)



data_smoothed = stroke_processed %>%
  cbind(
    fitmod$summary.fitted.values[, c("mean", "0.025quant", "0.5quant", "0.975quant")]
  ) %>% 
  as.data.frame() %>% 
  rename(
    lower0025 = `0.025quant`,
    median   = `0.5quant`,
    upper975 = `0.975quant`
  ) %>% 
  select(-geometry,-new_id,-Total)



write.xlsx(
  list(
    Stroke = data_smoothed
  ),
  file = "output/air_quality_spatial_Smoothing_stroke.xlsx",
  rowNames = FALSE
)





