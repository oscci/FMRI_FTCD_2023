#########################################################################################
# COLA fTCD Script: Calculate LI Values. Revised for BAN/OXF cases doing fMRI
#########################################################################################
# This script reads in data from 6 tasks (A-F) and calcuates LI values

# NB simple R script rather than in chunks, because interactive codes don't work with rmd.
# Interaction only used when checking, but allows for plots etc.

########################################################
#When you use settings to look at output (see lines 85-95), this program waits for input from user.
# In this case, it only runs properly if you run from source, which can be done using Ctrl+Shift+S.
#------------------------------------------------------------------------------------------
#You can run several files through a loop. But the program is not crashproof,
#and will crash if it encounters odd files. When this happens, make sure you run the last 2
#lines to ensure you save the results from files that run successfully.
#The program also gives the opportunity to comment on any features of files that are notable
#as you go through, by typing in the console. These comments will be stored in the xls file;
#You can also add comments there manually.

# Install packages

require(readxl) 
require(writexl)
require(tidyverse)
require(here)

########################################################
# Specify directory and other variable parameters
datadir <- "/Users/dorothybishop/Rprojects/COLA_Analysis_2022/ftcd_raw_data"

#This is the directory for the entire COLA sample, and contains raw fTCD data 
#I have updated it from OSF and it now has data for all participants.

# Read in sheet which lists all subjects and trial inclusions/exclusions
# This is the original sheet used in COLA analysis. 
mydf_loc <- "/Users/dorothybishop/Rprojects/COLA_Analysis_2022/data/ftcd_data_OSF.csv"
mydf <- read.csv(mydf_loc)
#For now we are going to drop 
#rows that don't correspond to the fMRI subset of participants.
mlist <- c("BAN01", "BAN02", "BAN03", "BAN04", "BAN05", "BAN06", "BAN07", "BAN08", "BAN09", "BAN10", "BAN11", "BAN12", "BAN13", "BAN14", "BAN15", "BAN16", "BAN17", "BAN18", "BAN19", "BAN20", "BAN21", "BAN22", "BAN23", "BAN24", "OXF01", "OXF02", "OXF03", "OXF04", "OXF05", "OXF06", "OXF07", "OXF08", "OXF09", "OXF10", "OXF11", "OXF12", "OXF13", "OXF14", "OXF15", "OXF16", "OXF17", "OXF18", "OXF19", "OXF20", "OXF21", "OXF22", "OXF23", "OXF24", "OXF25", "OXF26", "OXF27")
clist <- c(3448684, 3135443, 3181846, 3972866, 3972872, 3972851, 3972869, 3972886, 3972876, 3075829, 3176689, 3972867, 3972892, 3972898, 3484457, 3972871, 3405933, 3972887, 3399357, 3972896, 3680015, 3680022, 3680024, 3496140, 3679995, 3495903, 3679954, 3679947, 3679951, 3680010, 3679944, 3359167, 3495923, 3680011, 3160609, 3495898, 3680016, 3679970, 3357215, 3308424, 3972708, 3495965, 4688311, 3741358, 3667016, 3495952, 3495959, 3370826, 3460117, 3742941, 3972701)

w<- which(mydf$Gorilla_ID %in% clist)

mydf<-mydf[w,1:133]
mydf$ID <-NA

for (i in 1:nrow(mydf)){
  w<-which(clist ==mydf$Gorilla_ID[i])
  mydf$ID[i]<-mlist[w]
}
mydf<-mydf[,c(134,1:133)] #put fmri ID at start of columns

mydf<-mydf[order(mydf$ID),]

meansdir<- here("processed_data/ftcd_task_means/")
if(!file.exists(meansdir)){dir.create(meansdir)}
plotdir <- here("ftcd_LI_plots/")
if(!file.exists(plotdir)){dir.create(plotdir)}

#Some do not have any data in the cols re included trials. For these we will for now put 1 in.
# In fact, this is fixed later on, so ignore here
# w1<-which(names(mydf)=='A1')
# w2<-which(names(mydf)=='F18')
# for (i in 1:nrow(mydf)){
#   for (w in w1:w2){
#     if(is.na(mydf[i,w])){mydf[i,w]=1}
#   }
# }

mydf$Gorilla_ID<-as.character(mydf$Gorilla_ID) # unfactor these columns to avoid later difficulties
factor_cols <- c('Comment', 'nMark','nSpike','nExtreme','N','peak_LI','peak_latency','peak_se',
'peak_laterality','peak_odd','peak_even','mean_LI','mean_se','mean_laterality', 'mean_odd','mean_even','exclude')
mycolnum<-which(names(mydf)=='F18')
for (t in 1:6){
  for (col in 1: length(factor_cols)){
    mycol = paste0(LETTERS[t], '_', factor_cols[col])
    mycolnum = mycolnum+1
    mydf$temp <-NA
    names(mydf)[mycolnum] <- mycol
  }
}

########################################################
# You can change these settings to vary what output you see during the analysis
# Feel free to change these WITHOUT pushing the changes to github
checkmarkers=1; #set to 1 to see a sample of the file to check markers are there
initialdatacheck=1; #set to 1 to view raw data for each epoch
initialdatacheck1=0; # set to 1 to view epochs after normalisation
initialdatacheck2=0; #set to 1 to view epochs after heartbeat Correction
initialdatacheck3=0; # set to 1 to visualise after baseline correction
initialdatacheck4=1; # set to 1 to plot an average for each subject
########################################################

# Timings in secs
premarker=-12 # epoch start
basestart=-5 # baseline start
baseend=2 # baseline end
postmarker=25 # end of epoch
poistart=6 # period of interest start
poiend=23 # period of interest end

extremehi=140 # define values for rejecting bad epochs 
extremelo=60 # (% above/below mean of 100 in normed/corrected data)
samplingrate=25
heartratemax = 125  # Maximum heartrate that would be expected, in bpm
peakdiffmin = 60/heartratemax * samplingrate # The minumum number of samples expected between heartbeats, based on heartratemax
baselinecorrect=1 # correct for baseline
interpolatebad=2;#set to 2 to replace brief dropout/spiking with mean value for that channel
#number specified here is max number of bad datapoints corrected for

prepoints=premarker*samplingrate # these define the data point marking parts of the epoch
basestartpoint=basestart*samplingrate
baseendpoint=baseend*samplingrate
postpoints=postmarker*samplingrate
poistartpoints=poistart*samplingrate
poiendpoints=poiend*samplingrate

trialsperrun=18
mintrials = 10

# Tasks: A=Word Generation, B=Sentence Generation, C=Phonological Decision, 
# D=Word Comprehension, E=Sentence Comprehension, F=Syntactic Decision
tasks <- c("WG","SG","PD","WC","SC","SD")
ntasks <- length(tasks)


########################################################
# Loop through subjects

nsubj <- length(mydf$Gorilla_ID)

startsub <-1
endsub <- nsubj

for (mysub in startsub:endsub){
  mysubname <- mydf$Gorilla_ID[mysub]
  cat(paste0(mysubname),"\n")
  
  # Which site?
  wantcols = c(2,3,4,9) #sec, L, R,marker #select columns of interest to put in shortdat
  mysite <- mydf$Site[mysub]
  if (mysite == 'Lincoln')
  {wantcols = c(2,3,4,7)}
  if (mysite == 'UCL')
  {wantcols = c(2,3,4,11)}
  
  for (t in 1:6) {
    task <- tasks[t]
    
    # Set end of POI
    if (t == 1 | t == 2) {poiend <- 17}
    if (t > 2) {poiend <- 23}
    poiendpoints=poiend*samplingrate
    
    # Open relevant comment from results file
    comments_col <- which(colnames(mydf) == paste0(LETTERS[t], '_Comment'))
    mycomment<-mydf[mysub,comments_col]
    
    # Read exp data
    dataloc <- file.path(datadir, paste0("fTCD_",mysubname,"_",task,".exp"))
    
    if(file.exists(dataloc)){ # Only runs analysis for this task if data is found
      dat<-read.table(dataloc, skip = 6,  header =FALSE, sep ='\t')
      shortdat = data.frame(dat[,wantcols])
      colnames(shortdat) = c ("csec","L","R","marker")
      
      # downsample to 25 Hz by taking every 4th point
      rawdata = filter(shortdat, row_number() %% 4 == 0) # downsample to 25 Hz by taking every 4th point
      allpts = nrow(rawdata) # total N points in long file
      rawdata[,1] = (seq(from=1,to=allpts*4,by=4)-1)/100 #create 1st column which is time in seconds from start
      colnames(rawdata) = c("sec","L","R","marker")
      
      #-------------------------------------------------------
      # Brief plot of markers to check all OK
      #-------------------------------------------------------
      if (checkmarkers==1)
      {
        plot(rawdata$marker, type="l")
        cat("Press [enter] to continue")
        line <- readline()
      }
      
      #-----------------------------------------------------------
      #Now find markers; place where 'marker' column goes from low to high value
      #-----------------------------------------------------------
      mylen = nrow(rawdata); # Number of timepoints in filtered data (rawdata)
      markerplus = c(0 ,rawdata$marker); # create vectors with offset of one
      markerchan = c(rawdata$marker,0); 
      markersub = markerchan - markerplus; # start of marker indicated by large difference between consecutive data points
      meanmarker <- mean(rawdata$marker) # We will identify big changes in marker value that are > 5 sds
      markersize <- meanmarker+4*sd(rawdata$marker)
      origmarkerlist = which(markersub>markersize)
      norigmarkers = length(origmarkerlist)
      
      if (origmarkerlist[norigmarkers] > (mylen-postpoints))
      {myaddcomment<-paste('. Short last epoch in run')
      mycomment<-paste(mycomment,myaddcomment)
      } # indicates if there is a short last epoch; this may need disposing of
      
      excessmarkers=norigmarkers-trialsperrun
      # indicates if there are excess markers; hopefully these are practice trials. 
      # If the quantity does not indicate this, a comment is made in the 'Dispose of practice trials' 
      # section below. Also, check there aren't fewer than expected, and comment on this
      if (excessmarkers<0)
      {mycomment<-paste(mycomment,'. Fewer markers than expected')
      }
      
      # Check that markers are at least 37 s apart (ITI should be 38s)
      intervals=c(rawdata$sec[origmarkerlist],10000)-c(0,rawdata$sec[origmarkerlist])
      intervals=intervals[2:(length(intervals)-1)]
      # Ignore first and last values since these are arbitrary; other intervals should be around 30s 
      # but may be longer if recording interrupted. Shorter intervals indicate there have been spurious 
      # markers which will need dealing with
      if(min(intervals)<37)
      {myaddcomment<-paste('. Possible spurious markers')
      mycomment<-paste(mycomment,myaddcomment)
      }
      
      #---------------------------------------------------------
      # Look for practice trials, and dispose of them
      # Also identify unexpected extra markers; at present the
      # script is set to drop any excess markers from beginning of file 
      #---------------------------------------------------------
      if(excessmarkers>0)
      {
        if(excessmarkers==1) {
          markerlist<-origmarkerlist[(excessmarkers+1):(length(origmarkerlist))]
          mycomment<-paste(mycomment,'. Practice trials run 1 found and removed')
        } else {
          myaddcomment<-paste(excessmarkers,'. Unexpected markers found in run 1, investigate')
          mycomment<-paste(mycomment,myaddcomment)
          markerlist<-origmarkerlist[(excessmarkers+1):(length(origmarkerlist))] #If unexpected extra markers
          # found, drop earlier ones until maximum possible markers are retained; then continue
        }
      } else {
        markerlist<-origmarkerlist
      }
      nmarkers = length(markerlist)
      
      #---------------------------------------------------------
      # Make vector indicating trials to be be included/excluded
      # based on behaviour, and drop markers for trials not completed
      #---------------------------------------------------------
      mycols = c(which(colnames(mydf) == paste0(LETTERS[t], 1)) : which(colnames(mydf) == paste0(LETTERS[t], 18)))
      myinclude = mydf[mysub,mycols]
      myinclude = as.numeric(myinclude)
      #modified 24 Sep 2023 to allow for missing inclusion code - assume all 1 if so
      #However, there is one case (3405933) with one missing trial in one condition, so need to hand craft to cope with that
      #This is not ideal...
      
      if (is.na(myinclude[1]) )
      {myinclude <- rep(1,nmarkers)}
      if(length(myinclude)<trialsperrun){myinclude<-c(myinclude,0)}#to allow for case with missing marker
      ninclude = length(which(myinclude==1))
      
      #    myremove = which(myinclude==0) # 0 indicates trial not given
      #    if(length(myremove) > 0)
      #    {markerlist=markerlist[-myremove]
      #    }
      
      if (ninclude >= mintrials){ # Continue with analysis if there are enough good trials; otherwise skip it
        
        #-----------------------------------------------------------
        # identify extreme values; can also check each epoch visually
        #------------------------------------------------------------
        #droprej and spikerej give lower and upper limits of signal for L and R channels
        droprej = rep(0,2);
        spikerej = droprej # initialise spikerej and droprej with zero
        mymax = max(rawdata[,2:3])
        
        droprej[1] = quantile(rawdata$L,.0001)
        droprej[2] = quantile(rawdata$R,.0001)
        spikerej[1] = quantile(rawdata$L,.9999)
        spikerej[2] = quantile(rawdata$R,.9999)
        
        for(i in 1:2) # For left and right sensors
        {if(droprej[i]<1)
        {droprej[i]=1 #value cannot be 0 or less! Lowest droprej value is 1
        }
        }
        
        #----------------------------------------------------------
        # epoch the accepted trials into an array
        # This has 4 dimensions; trials,points, L/R, raw/normalised/heartcorr/baselined
        #-----------------------------------------------------------
        # myepoched will be the full epoched trial
        myepoched <- array(0, dim=c(nmarkers,postpoints-prepoints+1,2,4)) # Set up an empty matrix
        # mybit will be the bit within the POI
        mybit = matrix(data = NA, nrow = poiendpoints-basestartpoint, ncol = 2)
        
        for(mym in 1:nmarkers) # for trials
        { 
          index1=markerlist[mym]+prepoints # index1 is index of the timepoint at the start of the epoch
          index2=markerlist[mym]+postpoints # index2 is the index of the timepoint at the end of the epoch
          
          # If recording started late, the start of the epoch for trial 1 will be beyond the recorded range. 
          # If this doesn't affect the baseline period (ie, results will be unaffected), then replace with mean
          if (index1 < 0 & markerlist[mym]+basestartpoint > 0){
            cat("Recording started late. Padding start with zeros", "\n")
            replacement_mean_left = mean(rawdata[0:index2,2]) # Left hemisphere mean
            replacement_mean_right = mean(rawdata[0:index2,3]) # Right hemisphere mean
            myepoched[mym, ,1,1] = c(rep(replacement_mean_left,index1*-1+1),rawdata[0:index2,2])
            myepoched[mym, ,2,1] = c(rep(replacement_mean_right,index1*-1+1),rawdata[0:index2,3])
          }
          
          if (index1 > 1){
            myepoched[mym,,1,1]=rawdata[index1:index2,2] #L side
            myepoched[mym,,2,1]=rawdata[index1:index2,3] #R side
          }
          
          # Looks for data points lower than droprej or higher than spikerej. Only look between beginning of baseline and end of POI
          for(i in 1:2) # for left and right sides
          {rejpoints <- numeric(0) #coerces vector rejpoints to zero length between iterations 
          mybit[,i]=myepoched[mym, c((basestartpoint-prepoints):(poiendpoints-prepoints-1)), i, 1]
          thisbit = mybit[,i]
          
          # rejpoints is a list of points where signal indicates dropout or spiking
          rejpoints=c(rejpoints, which(thisbit < droprej[i]) + basestartpoint - prepoints -1); # identifies the indices of myepoched which will be marked as bad
          rejpoints=c(rejpoints, which(thisbit > spikerej[i]) + basestartpoint - prepoints -1);
          rejpoints=c(rejpoints, which(is.na(thisbit))) #triggered if epoch too short
          
          # if there are more than 2 rejected points, the whole epoch is marked as bad
          if(length(rejpoints)>interpolatebad)
          {myinclude[mym]=-1; #flag with -1; denotes drop this epoch; triggered by either channel
          }
          # if there are two or less (but more than zero)
          if(length(rejpoints)<=interpolatebad & length(rejpoints) > 0){
            for (p in 1:length(rejpoints)){
              myepoched[mym, rejpoints[p],i,1] = mean(myepoched[mym, c((basestartpoint-prepoints):(poiendpoints-prepoints-1)),i,1])}
            
          } # End of loop through rejpoints
          
          } # End of left / right loop
          
          if(mym==1)
          {badpoints=rejpoints
          }
          if(mym>1)
          {badpoints=c(badpoints,rejpoints)# keeps record of points with dropout/spiking between iterations
          }
          #-------------------------------------------
          # See epoch-by-epoch plots of raw data
          #-------------------------------------------
          
          # X axis will be time of full epoch
          timeline = rawdata$sec[1:(postpoints-prepoints+1)] #timeline used in all plots
          
          if(initialdatacheck==1) #set initialdatacheck to zero to avoid plotting
          {  myplotbit <- myepoched[mym, , ,1]
          #first plot the old values with no correction
          myylim <- range(c(range(na.omit(myplotbit[,1])),range(na.omit(myplotbit[,2]))))
          
          plot(timeline+premarker,myplotbit[,1],type="n",xlab='time (secs)',ylab='velocity',ylim=myylim)
          lines(timeline+premarker,myplotbit[,1],col="red")
          lines(timeline+premarker,myplotbit[,2],col="blue")
          
          #then overplot the corrected values in different colours
          lines(timeline+premarker,myepoched[mym,,1,1],col='pink')
          lines(timeline+premarker,myepoched[mym,,2,1],col='lightblue')
          abline(v = poistart, lty = 2, col = 'green')
          abline(v = poiend, lty = 2, col = 'green')
          abline(v = basestart, lty = 2)
          abline(v = baseend, lty = 2)
          
          mytitle=paste(mysubname, 'Trial:', mym,'Include = ',myinclude[mym])
          title(mytitle)
          cat("Press 0 to reject trial. Press 1 to include trial. To retain current inclusion/exclusion status, press ENTER")
          myoverride <- as.integer(readline(prompt = ""))
          
          # These if statements process the user's manual responses 
          if(is.na(myoverride)) # If the user presses enter but fails to press a number,
          {myoverride=myinclude[mym]  # keep the original value
          }              # This means exclusion/inclusion is retained according to the automated system. 
          if(myoverride==1)
          {if (myinclude[mym] != 1){
            # If you include a trial that was previously excluded, add a comment
            myaddcomment<-paste('. Manual include trial ',mym)
            mycomment<-paste(mycomment,myaddcomment)
          }
            myinclude[mym] = 1}
          if(myoverride!=1)
          {myinclude[mym] = -1
          # If you exclude a trial that was previously excluded, add a comment
          myaddcomment<-paste('. Manual exclude trial ',mym)
          mycomment<-paste(mycomment,myaddcomment)}
          }
          
        } #next epoch
        
        #--------------------------------------------------------
        # Remove deleted epochs (originals in origdata; 
        # myepoched updated so only has retained epochs)
        #--------------------------------------------------------
        nspikes=length(badpoints) # add number of spiking/dropout points to table for saving
        # Identify
        keepmarkers=which(myinclude==1)
        origdata=myepoched #keep this so can reconstruct
        myepoched=myepoched[keepmarkers,,,] #file with only accepted epochs
        nmarkers2=length(keepmarkers)
        
        #---------------------------------------------------------
        # Normalise to mean of 100 (see Deppe et al, 2004)
        # Multiply by 100 and divide by overall mean value
        # ensures results are independent of angle of insonation
        #----------------------------------------------------------
        meanL=mean(myepoched[,,1,1], na.rm='TRUE')
        meanR=mean(myepoched[,,2,1], na.rm='TRUE')
        myepoched[,,1,2]=(100*myepoched[,,1,1])/meanL #last dim of myepoched is 2 for the normalised data
        myepoched[,,2,2]=(100*myepoched[,,2,1])/meanR
        
        # Short final epochs have NAs in them. Replace with zero to avoid errors.
        for (x in 1:length(myepoched[nmarkers2,,1,2])){
          
          if (is.na(myepoched[nmarkers2,x,1,2])){
            cat("Recording ended early. Replacing NAs with zeros", "\n")
            myepoched[nmarkers2,x,1,2] = 0 # Left hemisphere
            myepoched[nmarkers2,x,2,2] = 0 # Right hemisphere
          }
        }
        
        #---------------------------------------------------------
        # See plots of normed epochs
        #---------------------------------------------------------
        if(initialdatacheck1==1)
        {for(mym in 1:nmarkers2)
        {plot(timeline+premarker,myepoched[mym,,1,2],type="n",xlab='time (secs)',ylab='velocity')
          lines(timeline+premarker,myepoched[mym,,1,2],col='pink')
          lines(timeline+premarker,myepoched[mym,,2,2],col='lightblue')
          title('After normalization')
          cat("Press [enter] to continue")
          line <- readline()
        }
        }
        
        #----------------------------------------------------------
        # Find heart beat markers and put corrected values in col 3
        # of 4th dimension of myepoched
        #----------------------------------------------------------
        #Find peaks with moving window, looking for troughs in heartbeat
        
        for(mym in 1:nmarkers2)
        {peaklist=numeric(0)
        pdiff=numeric(0)
        badp=numeric(0)
        thisbit=myepoched[mym,,1,2]
        mypts=length(na.omit(thisbit))
        
        for(i in seq(6,mypts-6,2))
        {if(
          (thisbit[i] > thisbit[i-5])      # Check that ith value is greater than the value 5 back
          && (thisbit[i-1] > thisbit[i-5]) # Check that the previous value is greater than the value 5 back
          && (thisbit[i] > thisbit[i+5])   # Check that the ith value is greater than the value 5 ahead
          && (thisbit[i+1]>thisbit[i+5]))  # Check that the next value is greater than the value 5 ahead
        {peaklist=c(peaklist,i)
        }
        }
        
        # Check that the heartbeats are spaced by far enough!
        pdiff <- peaklist[2:length(peaklist)]-peaklist[1:(length(peaklist)-1)] # pdiff is a list of the number of samples between peaks
        badp<-which(pdiff<peakdiffmin) # badp is a list of the pdiff values that are less than peakdiffmin
        if (length(badp) != 0)
        {peaklist<-peaklist[-(badp+1)] # update peaklist, removing peaks identified by badp
        }
        peaklist=c(1,peaklist,mypts) #top and tail the list 
        
        peakn=length(peaklist)
        for (p in 1:(peakn-1))
        {myrange=seq(peaklist[p],peaklist[p+1]) # the indices where the heartbeat will be replaced
        thisheart1=mean(myepoched[mym,myrange,1,2]) # the new values that will be replaced
        thisheart2=mean(myepoched[mym,myrange,2,2])
        myepoched[mym,myrange,1,3]=thisheart1
        myepoched[mym,myrange,2,3]=thisheart2
        }
        }
        
        #----------------------------------------------------------
        # See plot after heartbeat correction
        #----------------------------------------------------------
        if (initialdatacheck2==1)
        {for(mym in 1:nmarkers2 )
        {plot(timeline+premarker,myepoched[mym,,1,3],type="n",xlab='time (secs)',ylab='velocity')
          lines(timeline+premarker,myepoched[mym,,1,3],col='pink')
          lines(timeline+premarker,myepoched[mym,,2,3],col='lightblue')
          mytitle=paste('Trial after heart beat correction, trial =', mym)
          title(mytitle)
          cat ("Press [enter] to continue")
          line <- readline()
        }
        }
        
        #----------------------------------------------------------
        # Find mean for baseline and subtract this.
        # This amounts to baseline correction...
        #----------------------------------------------------------
        nepochbase=nmarkers2
        basepoints=(basestartpoint-prepoints):(baseendpoint-prepoints) #all baseline points within epoch
        if (baselinecorrect==1)
        {for (mym in 1:nmarkers2)
        {basemeanL=mean(myepoched[mym,basepoints,1,3]) #last dim is 3, which is HB corrected
        basemeanR=mean(myepoched[mym,basepoints,2,3])
        myepoched[mym,,1,4]=100+myepoched[mym,,1,3]-basemeanL #last dim 4 is HB and baseline
        myepoched[mym,,2,4]=100+myepoched[mym,,2,3]-basemeanR
        }
        }
        
        #--------------------------------------------------------
        # Plot after HB correction and baseline correction
        #--------------------------------------------------------
        if(initialdatacheck3==1)
        {for(mym in 1:nmarkers2 )
        {plot(timeline+premarker,myepoched[mym,,1,4],type="n",xlab='time (secs)',ylab='velocity')
          lines(timeline+premarker,myepoched[mym,,1,4],col='red')
          lines(timeline+premarker,myepoched[mym,,2,4],col='blue')
          mytitle=paste('Trial after baseline correction, trial =',mym)
          title(mytitle)
          text(-5,110,'blue=R\n red=L\n',cex=.75)
          cat ("Press [enter] to continue")
          line <- readline()
        }
        }
        
        #--------------------------------------------------------
        # Find and exclude epochs with extreme values in period 
        # between start of baseline and end of POI
        #---------------------------------------------------------
        keepepoch=rep(1,nmarkers2) #initialise for inclusions
        for(mym in 1:nmarkers2)
        {extremerange=c(which(myepoched[mym,1:(poiendpoints-basestartpoint),1:2,4]>extremehi),
                        which(myepoched[mym,1:(poiendpoints-basestartpoint),1:2,4]<extremelo))
        if(length(extremerange)>0 )
        {keepepoch[mym]=0
        }
        if(mym==1)
        {allextreme=extremerange
        }
        if(mym>1)
        {allextreme=c(allextreme,extremerange) #keeps record of extreme values across trials
        }
        }
        acceptableepochs=which(keepepoch==1)
        nextreme=length(allextreme) #report number of extreme values across trials
        
        #--------------------------------------------------------
        # Get grand average
        #--------------------------------------------------------
        finalepochs=myepoched[acceptableepochs,,,4]
        myN=dim(finalepochs)[1] #initialise vectors for laterality stats
        
        # Average over all included trials
        Lmean <- apply(finalepochs[,,1], c(2), mean)
        Rmean <- apply(finalepochs[,,2], c(2), mean)
        LRdiff=Lmean-Rmean
        
        # Specify period of interest (POI)
        baseoffset=-premarker*samplingrate
        rangestart=baseoffset+poistartpoints
        rangeend=baseoffset+poiendpoints
        
        #--------------------------------------------------------
        # Calculate peak LI stats
        #--------------------------------------------------------    
        # Identify peak 
        mymax=max(LRdiff[rangestart:rangeend])
        mymin=min(LRdiff[rangestart:rangeend])
        myside=1
        mylatpeak=mymax
        if(-mymin>mymax)
        {myside=-1 #R biased LI
        mylatpeak=mymin
        } #R peak > L peak
        
        mytimepeak=first(which(LRdiff==mylatpeak))
        peak_latency=(mytimepeak-baseoffset)/samplingrate #need to subtract points for baseline
        mypeakrange=seq(mytimepeak-25,mytimepeak+25) #actual points ie includes baseline
        
        # Calculate peak LI
        peak_LI=round(mean(LRdiff[mypeakrange]),3)
        
        # Extract trial-by-trial data for peak SE
        indLI=numeric(0) #initialise null vector
        indLI_mean=numeric(0)
        for (m in 1:myN)
        {indLI=c(indLI,mean(finalepochs[m,mypeakrange,1]-finalepochs[m,mypeakrange,2]))
        inddiff <- finalepochs[m,rangestart:rangeend,1] - finalepochs[m,rangestart:rangeend,2]
        indLI_mean =c(indLI_mean,mean(inddiff)) ## This is now correct!!!
        }
        peak_sd <- sd(indLI)
        peak_se <- round(peak_sd/sqrt(myN), 3)
        
        # Calculate whether laterality is significantly left, right or neither (bilateral)
        latdir=c("R","bilat","L")
        lowCI=as.numeric(format(peak_LI-myside*peak_se*1.96,digits=3))
        lateralised=myside
        if((myside*lowCI)<0) {lateralised=0}
        peak_laterality=latdir[lateralised+2]
        
        # Calculate peak LI from odd or even trials only
        odds<-seq(from=1,to=myN,by=2)
        evens<-seq(from=2,to=myN,by=2)
        Lmeanodd<-apply(finalepochs[odds,,1],c(2),mean)
        Lmeaneven<-apply(finalepochs[evens,,1],c(2),mean)
        Rmeanodd<-apply(finalepochs[odds,,2],c(2),mean)
        Rmeaneven<-apply(finalepochs[evens,,2],c(2),mean)
        LRdiffodd<-Lmeanodd-Rmeanodd
        LRdiffeven<-Lmeaneven-Rmeaneven
        peak_odd <- round(mean(LRdiffodd[mypeakrange]), 3)
        peak_even <- round(mean(LRdiffeven[mypeakrange]), 3) #NB LI for even and odd computed at same peak as full LI
        
        #--------------------------------------------------------
        # Calculate mean LI stats
        #--------------------------------------------------------  
        # Calculate mean LI
        mean_LI <- round(mean(LRdiff[rangestart:rangeend]), 3)
        
        # SE for mean LI
        mean_sd <- sd(indLI_mean)
        mean_se <- round(mean_sd/sqrt(myN), 3)
        
        # Calculate whether laterality is signficantly left, right or neither (bilateral)
        myside=1
        if(mean_LI < 0)
        {myside=-1} #R biased LI
        lowCI=as.numeric(format(mean_LI-myside*mean_se*1.96,digits=3))
        lateralised=myside
        if((myside*lowCI)<0) {lateralised=0}
        mean_laterality=latdir[lateralised+2]
        
        # Calculate mean LI from odd or even trials only
        mean_odd=round(mean(LRdiffodd[rangestart:rangeend]), 3)
        mean_even=round(mean(LRdiffeven[rangestart:rangeend]), 3)
        
        #----------------------------------------------------------
        #Plot and save overall  laterality curve
        #----------------------------------------------------------
        timelinelong=rawdata$sec[1:(postmarker*25-prepoints+1)]+premarker
        
        if (initialdatacheck4==1)
        {
          plot(timelinelong,Lmean, type="n",ylab='mean blood flow',xlab='time(s)',ylim=c(90,120)) #set up plot - doesn't actually plot anything
          lines(timelinelong,Lmean,col='red')
          lines(timelinelong,Rmean,col='blue')
          lines(timelinelong,(100+LRdiff),col='black')
          abline(v = poistart, lty = 2, col = 'green')
          abline(v = poiend, lty = 2, col = 'green')
          abline(v = basestart, lty = 2)
          abline(v = baseend, lty = 2)
          text(-4,110,'blue=R\n red=L\n black=(L-R) +100',cex=.75)
          mytitle <- paste0("Subject ", mysubname, ", Task ", task)
          title(mytitle)
          
          cat ("Press [enter] to continue")
          line <- readline()
          
          png(filename = file.path(plotdir, paste0("LI_Plot_",mysubname,"_",task,".png")))
          
          plot(timelinelong,Lmean, type="n",ylab='mean blood flow',xlab='time(s)',ylim=c(90,120)) #set up plot - doesn't actually plot anything
          lines(timelinelong,Lmean,col='red')
          lines(timelinelong,Rmean,col='blue')
          lines(timelinelong,(100+LRdiff),col='black')
          abline(v = poistart, lty = 2, col = 'green')
          abline(v = poiend, lty = 2, col = 'green')
          abline(v = basestart, lty = 2)
          abline(v = baseend, lty = 2)
          text(-4,105,'blue=R\n red=L\n black=(L-R) +100',cex=.75)
          mytitle = paste0("Subject ", mysubname, ", Task ", task)
          title(mytitle)
          
          dev.off()
        }
        
        
        #------------------------------------------------------
        # Writes data to file.
        #------------------------------------------------------
        
        mydf[mysub, mycols] <- myinclude
        #Prepare stats for individual condition for saving to file
        savedata <- c(norigmarkers, nspikes, nextreme, myN,
                      peak_LI, peak_latency, peak_se, peak_laterality, peak_odd, peak_even,
                      mean_LI, mean_se, mean_laterality, mean_odd, mean_even)
        startcol <- which(colnames(mydf) == paste0(LETTERS[t], '_nMark'))
        endcol <- which(colnames(mydf) == paste0(LETTERS[t], '_mean_even'))
        
        mydf[mysub,startcol:endcol] <- savedata
        
        averageddata <- data.frame("Sent_L" = Lmean,
                                   "Sent_R" = Rmean)
        
        # # Print averaged epoch data to file
        if(length(keepmarkers)>=8){
          mymeanLR<-data.frame(matrix(ncol=5,nrow=mypts)) ###TESTING WAS 801
          mymeanLR[,1]<-as.integer(mysub)
          alltime<-seq(from=premarker, to=postmarker, by=.04)
          mymeanLR[,2]<-alltime
          mymeanLR[,3]<-Lmean
          mymeanLR[,4]<-Rmean
          mymeanLR[,5]<-Lmean-Rmean
          colnames(mymeanLR)<-c("ID", "time", "Lmean", "Rmean", "meanDiff")
          csvFile2 <- file.path(meansdir, paste0(mysubname,"_",task,".csv"))
          write.csv(mymeanLR, csvFile2, row.names=F)
        }
        
      }
      excludecol = which(colnames(mydf) == paste0(LETTERS[t], '_exclude'))
      mydf[mysub, excludecol] = 0
      
      if (ninclude < mintrials){
        myaddcomment <- "Not enough data"
        mycomment<-paste(mycomment,myaddcomment)
        mydf[mysub, excludecol] = 1
      }
      
      if(nmarkers2 < mintrials){
        myaddcomment <- "Not enough data"
        mycomment<-paste(mycomment,myaddcomment)
        mydf[mysub, excludecol] = 1
      }
    } 
    
    
    
    
    if(!file.exists(dataloc)){
      myaddcomment <- "No data"
      mycomment<-paste(mycomment,myaddcomment)
      mydf[mysub, excludecol] = 1
    }
    mydf[mysub,comments_col] <- mycomment
    
  } # End loop through tasks
  
} # End loop through subjects

# Print results file
writefile <- here("processed_data","ftcd_data_short.csv")
write.csv(mydf, file = writefile, row.names=F)

writeLines(capture.output(sessionInfo()), "ftcd_preprocessing_sessionInfo.txt")




