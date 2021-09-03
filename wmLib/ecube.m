classdef ecube
    % Ecube Data Processing
    properties
        filename
        NetcamFrameRate           = 60
        DigitalsamplingRate       = 25000;
        netcamDChannel            = 1;
        triggerDchannel           = 2;
        mlstrobeDChannel          = 3;
        photodiodeDChannel        = 4;
        eventcodeDChannel         = 41:64;
        eyeXAChannel              = 1;
        eyeYAChannel              = 2;
        photodiodeAChannel        = 3;
        RecordedAnalogChannels    = 3;
        AnalogvoltPerBit          = 3.0517578125e-4;
        AsciiShift                = 200000;
        DigitalTimeStamp  
        AnalogTimeStamp
        predefinedEvents
        netcam_sync
        netcam_video_start
        photodiode_pulse
        trigger_pulse
        eyeXY
        time
        eventCode
        expHeader
        TrialwiseBehavioralCodes
        TrialwiseFooter
    end
    
    methods
        function obj = ecube(file_name)
            if nargin==1
                obj.filename                    = file_name;
                obj.predefinedEvents            = obj.loadevents();
                obj                             = read_digitalchannel(obj);
                obj                             = read_analogchannel(obj);
                [behavCodes,TrialFooter]        = wm_eventcodedecoding(obj.eventCode,obj.predefinedEvents);
                obj.TrialwiseBehavioralCodes    = behavCodes;
                obj.TrialwiseFooter             = TrialFooter;
            end
        end
        
        
        function obj = read_digitalchannel(obj)
            digitaldata     = []; DTS = [];
            fid             = fopen(obj.filename.Digital, 'r');
            dts             = fread(fid,1,'uint64=>uint64'); % read eCube 100MHz timestamp from start of every file
            DTS             = cat(1,DTS,dts);
            d               = fread(fid,'uint64=>uint64');
            digitaldata     = cat(1,digitaldata,d);
            fclose(fid);
            obj.time                = vec((0:length(digitaldata)-1)*(1/obj.DigitalsamplingRate));
            obj.DigitalTimeStamp    = DTS;
            obj.netcam_sync         = wm_bitExtract(digitaldata,obj.netcamDChannel);
            obj.photodiode_pulse    = wm_bitExtract(digitaldata,obj.photodiodeDChannel);
            obj.trigger_pulse       = wm_bitExtract(digitaldata, obj.triggerDchannel);
            ml_strobe               = wm_bitExtract(digitaldata,obj.mlstrobeDChannel);
            obj                     = wm_eventcodeExtract(obj,digitaldata,ml_strobe);
            obj.netcam_video_start  = find_start_of_video_recording(obj,1);
        end
        
        function obj = read_analogchannel(obj)
            ain = []; ATS = [];
            voltPerBit          = obj.AnalogvoltPerBit;
            fid                 = fopen(obj.filename.Analog, 'r');
            ats                 = fread(fid,1,'uint64=>uint64'); % read eCube 100MHz timestamp from start of every file
            ATS                 = cat(1,ATS,ats);
            a                   = fread(fid, [obj.RecordedAnalogChannels,inf], 'int16=>single');
            ain                 = cat(2,ain,a*voltPerBit)';
            fclose(fid);
            obj.eyeXY           = ain(:,[obj.eyeXAChannel,obj.eyeYAChannel]);
            obj.photodiode_pulse= ain(:,obj.photodiodeAChannel);
            obj.AnalogTimeStamp = ATS;
        end
       
            
        function obj=wm_eventcodeExtract(obj,digitaldata,strobe)
            channel = obj.eventcodeDChannel;
            E3time    = obj.time;
            % Ignoring unspecified channels
            first_channel=channel(1);
            N=length(channel);
            if(first_channel>1)
                digitaldata=bitshift(digitaldata,-(first_channel-1)); % ignoring the first N bits
            end
            value=bitand(digitaldata,2^N-1); % selecting the fi
            value=double(value);
            
            strobe_index = (diff(strobe)==1); % 1 = rising edge, -1 for falling edge of strobe bit
            strobe_offset = 0; strobe_index = strobe_index + strobe_offset;
            value(~strobe_index)=0; % discarding event code replicates;
            
            % Extracting event codes
            event_code_time     = E3time(strobe_index==1);
            event_codes         = value(strobe_index==1);
            Code(:,1)           = vec(event_codes);
            Code(:,2)           = vec(event_code_time);
            
            % Copying headers and Event codes separately
            fileStart         = obj.predefinedEvents.exp.filesStart;
            fileStop          = obj.predefinedEvents.exp.filesStop;
            startIndex = find(Code==fileStart);stopIndex  = find(Code==fileStop);
            
            if(~isempty(startIndex) && ~isempty(stopIndex)) % copying header if exist
                header_content = Code((startIndex+1):(stopIndex-1)) - obj.AsciiShift;
                header_content = double(header_content);
                obj.expHeader   = wm_headerUint16Double(header_content);
            else
            end
            
            % Copy Event codes
            firstTrialStart    = find(Code==obj.predefinedEvents.trl.start,1);
            obj.eventCode      = Code(firstTrialStart:end,:);
        end
        
        function video_start_time =find_start_of_video_recording(obj,figFlag)
            % figFlag is a optional argument. In default condition plot
            % will be generated. To ignore plot you need to pass 0. 
            if(~exist('figFlag','var')), figFlag =1; end
            t           = obj.time;
            netcamsync  = obj.netcam_sync;
            camera_fps  = obj.NetcamFrameRate;
            fs          = obj.DigitalsamplingRate; 
            %% Finding approximate the start of recording
            buffer_time=3;
            Param=floor(fs/camera_fps);
            wind=fs;
            Nsteps=length(t)/wind; % 1s steps
            E=[];
            for i=1:Nsteps
                index=(i-1)*wind+(1:wind);
                E(i)=mean(netcamsync(index));
            end
            approx_start_time=find(E>=0.45,1);
            
            index=find(t>(approx_start_time-buffer_time) &t<(approx_start_time));
            % figure; plot(t(index),netcamsync(index))
            SelectedPulse=netcamsync(index);
            SelectedTime=t(index);
            
            %% Finding exact start of recording
            change=SelectedPulse(1);
            count=0;
            X=[];
            T=[];
            for i=1:length(SelectedPulse)
                value=SelectedPulse(i);
                if(value==change)
                    count=count+1;
                else
                    change=SelectedPulse(i);
                    X=[X;count];
                    T=[T;SelectedTime(i)];
                    count=0;
                end
            end
            Y=X./Param;
            index=find(Y>0.4 & Y<0.6,1);
            video_start_time=T(index-1);
            
            if(figFlag==1)
            figure;
            plot(SelectedTime,SelectedPulse);hold on;
            line([video_start_time,video_start_time],[0,1],'Color','red','LineStyle','--','LineWidth',2);
            title_str=sprintf('Video Start time = %2.4f',video_start_time);
            title(title_str);
            xlabel('Relative Time from start of ECube Recording');
            ylabel('Netcam Digital Pulse')
            end
        end
        
    end
    methods (Static)
        function event = loadevents()
            if(exist('ml_loadEvents')),[event.err, event.pic, event.aud, event.bhv,event.rew, event.exp, event.trl, event.check, event.ascii] = ml_loadEvents();
            else
                fprintf('\n ml_loadEvents .mat file missing \n');
            end
        end
    end
end

