# Process Picarro data for DWP lab experiment
# Ben Bond-Lamberty December 2015

source("0-functions.R")

SCRIPTNAME  	<- "4-plots.R"
FLUXDATA      <- paste0(OUTPUT_DIR, "fluxdata.csv")  # output from script 3
FLUXDATA2      <- paste0(OUTPUT_DIR, "fluxdata_247check.csv")  # output from script 3


# ==============================================================================
# Main 

sink(file.path(outputdir(), paste0(SCRIPTNAME, ".log.txt")), split=T) # open log

printlog("Welcome to", SCRIPTNAME)

printlog("Reading in flux data...")
fluxdata <- read_csv(FLUXDATA)
print_dims(fluxdata)


fluxdata$Depth_cm <- factor(fluxdata$Depth_cm, levels=c("0-30", "30-60", "60-90", "90-120", 
                                                        "120-150", "150-180", "180-210", "210-240", "Ambient", "Blank"))

printlog("Flux rate summary:")
fluxdata %>%
  group_by(Depth_cm) %>%
  summarise(CO2_flux_umol_g_day = mean(CO2_flux_umol_g_s, na.rm=TRUE) * 60 * 60 * 24,
            CH4_flux_umol_g_day = mean(CH4_flux_umol_g_s, na.rm=TRUE) * 60 * 60 * 24
  ) %>%
  print()


# Total cumulative C by Site, Depth, and gas
fluxdata %>% 
  group_by(Site, Depth_cm, DWP_core) %>% 
  summarise(cum_CO2_mgC = max(net_cum_CO2_mgC, na.rm = TRUE),
            cum_CH4_mgC = max(net_cum_CH4_mgC, na.rm = TRUE)) %>%
#  group_by(Site, Depth_cm) %>%
  summarise(cum_CO2_mgC_sd = sd(cum_CO2_mgC),
            cum_CO2_mgC = mean(cum_CO2_mgC),
            cum_CH4_mgC_23 = sd(cum_CH4_mgC),
            cum_CH4_mgC = mean(cum_CH4_mgC)) -> 
  cumfluxdata

p <- ggplot(cumfluxdata, aes(Depth_cm, cum_CO2_mgC, fill = Site)) + 
  geom_bar(stat='identity') + guides(fill = FALSE) +
  geom_errorbar(aes(ymin = cum_CO2_mgC-cum_CO2_mgC_sd, 
                    ymax = cum_CO2_mgC + cum_CO2_mgC_sd)) +
  facet_grid(Site~.)
print(p)
save_plot("evolved_C")


printlog("Plotting...")

# Summary by depth and core of fluxes and pre-injection rates

fluxdata$DepthCore <- paste(fluxdata$Depth_cm, fluxdata$DWP_core)
p <- qplot(ELAPSED_TIME_s/60/60, cumCO2_flux_mgC, color=Depth_cm, data=fluxdata, geom="line") + facet_wrap(~DepthCore) 
p <- p + geom_line(aes(y=cumCO2_flux_mgC_pre), linetype = 2)
p <- p + xlab("Time since injection (hr)") 
print(p)
save_plot("depth_core")

# Summary by depth

boxplotdata <- melt(fluxdata, id.vars="Depth_cm", measure.vars = c("CO2_flux_umol_g_s", "CH4_flux_umol_g_s"))
p <- ggplot(boxplotdata, aes(Depth_cm, value * 60 * 60 * 24)) + geom_boxplot() + facet_grid(variable~., scales="free")
p <- p + ylab("mg C/g soil/day") + ggtitle("Gross fluxes")
p <- p + coord_flip() + scale_x_discrete(limits=rev(levels(fluxdata$Depth_cm)))
print(p)
save_plot("depth_boxplot")

m_CO2 <- lm(CO2_flux_umol_g_s ~ Depth_cm + Site, data=fluxdata)
print(summary(m_CO2))
m_CH4 <- lm(CH4_flux_umol_g_s ~ Depth_cm + Site, data=fluxdata)
print(summary(m_CH4))

# Summary by depth and site
p <- ggplot(fluxdata, aes(Depth_cm, CO2_flux_umol_g_s * 60 * 60 * 24)) + geom_boxplot() 
p <- p + facet_grid(Site ~ .)
p <- p + ylab("CO2 flux (mg C/g soil/day)") + ggtitle("Gross CO2 fluxes")
p <- p + coord_flip() + scale_x_discrete(limits=rev(levels(fluxdata$Depth_cm)))
print(p)
save_plot("depth_CO2_boxplot")
p <- ggplot(fluxdata, aes(Depth_cm, CH4_flux_umol_g_s * 60 * 60 * 24)) + geom_boxplot() 
p <- p + facet_grid(Site ~ .)
p <- p + ylab("CH4 flux (mg C/g soil/day)") + ggtitle("Gross CH4 fluxes")
p <- p + coord_flip() + scale_x_discrete(limits=rev(levels(fluxdata$Depth_cm)))
print(p)
save_plot("depth_CH4_boxplot")


# Gas evolution over time plots

fluxdata_labels <- fluxdata %>%
  group_by(Trt, Rep, DWP_core, Depth_cm) %>%
  arrange(ELAPSED_TIME_s) %>%
  summarise(ELAPSED_TIME_s = last(ELAPSED_TIME_s),
            cumCO2_flux_mgC = last(cumCO2_flux_mgC),
            cumCH4_flux_mgC = last(cumCH4_flux_mgC))

p <- ggplot(fluxdata, aes(ELAPSED_TIME_s/60/60, cumCO2_flux_mgC, color=Trt, group=DWP_core))
p <- p + geom_line() + facet_wrap(~Depth_cm)
p <- p + xlab("Elapsed time (hours)") + ggtitle("Gross CO2 fluxes")
p <- p + geom_text(data=fluxdata_labels, aes(label=DWP_core), vjust=-0.5, size=3, show.legend = FALSE)
print(p)
save_plot("cumulative_CO2")

p <- ggplot(fluxdata, aes(ELAPSED_TIME_s/60/60, cumCH4_flux_mgC, color=Trt, group=DWP_core))
p <- p + geom_line() + facet_wrap(~ Depth_cm)
p <- p + xlab("Elapsed time (hours)") + ggtitle("Gross CH4 fluxes")
p <- p + geom_text(data=fluxdata_labels, aes(label=DWP_core), vjust=-0.5, size=3, show.legend = FALSE)
print(p)
save_plot("cumulative_CH4")

p <- ggplot(fluxdata, aes(ELAPSED_TIME_s/60/60, cumCO2_flux_mgC + cumCH4_flux_mgC, color=Depth_cm, group=DWP_core))
p <- p + geom_line() + facet_wrap(~Depth_cm)
p <- p + xlab("Elapsed time (hours)") + ggtitle("Gross C fluxes")
p <- p + geom_text(data=fluxdata_labels, aes(label=DWP_core), vjust=-0.5, size=3, show.legend = FALSE)
print(p)
save_plot("cumulative_C")


# Pre and post-injection comparisons

fluxdata$SamplePoint <- as.factor(fluxdata$SamplePoint)
p <- qplot(ELAPSED_TIME_s/60/60, CO2_flux_umol_g_s, data=fluxdata, group=DWP_core, color=Site) 
p <- p + geom_vline(xintercept = 0, linetype = 2) + 
  facet_wrap(~Depth_cm, scales="free") + geom_smooth()
p <- p + xlab("Elapsed time (hrs)")
print(p)
save_plot("CO2_flux_site_time")
p <- qplot(ELAPSED_TIME_s/60/60, CH4_flux_umol_g_s, data=fluxdata, group=DWP_core, color=Site) 
p <- p + geom_vline(xintercept = 0, linetype = 2) + 
  facet_wrap(~Depth_cm, scales="free") + geom_smooth()
p <- p + xlab("Elapsed time (hrs)")
print(p)
save_plot("CH4_flux_site_time")
p <- qplot(ELAPSED_TIME_s/60/60, CO2_flux_umol_g_s, data=fluxdata, group=DWP_core, color=SamplePoint, shape=Site) 
p <- p + geom_vline(xintercept = 0, linetype = 2) + 
  facet_wrap(~Depth_cm, scales="free") + geom_smooth()
p <- p + xlab("Elapsed time (hrs)")
print(p)
save_plot("CO2_flux_sample_time")
p <- qplot(ELAPSED_TIME_s/60/60, CH4_flux_umol_g_s, data=fluxdata, group=DWP_core, color=SamplePoint, shape=Site) 
p <- p + geom_vline(xintercept = 0, linetype = 2) + 
  facet_wrap(~Depth_cm, scales="free") + geom_smooth()
p <- p + xlab("Elapsed time (hrs)")
print(p)
save_plot("CH4_flux_sample_time")



fd_summary <- fluxdata %>% 
  group_by(Depth_cm, Trt) %>% 
  summarise(CO2 = 60 * 60 * mean(CO2_flux_umol_g_s),
            CH4 = 60 * 60 * mean(CH4_flux_umol_g_s))
p <- ggplot(fd_summary, aes(Depth_cm, CO2, fill = Trt)) + geom_bar(stat="identity", position="dodge")
p <- p + ylab("Mean CO2 flux (µmol/g/hr")
print(p)
save_plot("CO2_flux_comparison")
p <- ggplot(fd_summary, aes(Depth_cm, CH4, fill = Trt)) + geom_bar(stat="identity", position="dodge")
p <- p + ylab("Mean CH4 flux (µmol/g/hr")
print(p)
save_plot("CH4_flux_comparison")


# We ran a subsequent check using cores, 2, 4, and 7, monitoring them continuously to make sure
# we didn't miss any methane or CO2 'burps'. Split off those data separately.

printlog("Reading in secondary flux data...")
fluxdata_247check <- read_csv(FLUXDATA2)

printlog("Plotting injection 2 data...")
checkplotdata <- fluxdata_247check %>% 
  select(ELAPSED_TIME_s, Depth_cm, DWP_core, cumCO2_flux_mgC, cumCH4_flux_mgC) %>%
  mutate(cumC_flux_mgC = cumCO2_flux_mgC + cumCH4_flux_mgC) %>%
  melt(measure.vars=c("cumCO2_flux_mgC", "cumCH4_flux_mgC", "cumC_flux_mgC"))
p <- ggplot(checkplotdata, aes(ELAPSED_TIME_s/60/60, value, color=factor(DWP_core)))
p <- p + geom_line() + facet_grid(variable ~ ., scales='free_y')
p <- p + xlab("Elapsed time (hours)") + ylab("Cumulative C flux (mg C)")
print(p)
save_plot("injection2")



save_data(fluxdata, scriptfolder=FALSE)
save_data(fluxdata_247check, scriptfolder=FALSE)

printlog("All done with", SCRIPTNAME)
print(sessionInfo())
sink() # close log
