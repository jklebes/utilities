classdef expReader < handle
%{
    Object to read image sequences in a folder. Images should have a common
    naming pattern (eg. "img_0202.tif"). If only the path to the images is
    provided, the program will guess the pattern to read the images. It is
    used in many other functions for convenience.
    
    INPUTS
        expFolder: path to directory containing the sequence of images
        
        timePoints: array containing the indices of the images to be read.
                    Optional, by default read all
        
        format: cell array of dimensions 1x3. it contains 3 strings:
                {'image_file_header_', 'number_format', 'image_extension'}
                for example: {'img_', '%04d', '.tif'} will read all the
                files begining with img_ followed by a whole number
                composed by 4 digits and ended by .tif (eg img_0202.tif).
                Optional. the program will guess the format, but if the
                directory contains other files in addition to images it may
                fail
        
        mode: explore the sequence forwards (1) or backwards (-1).
        Optional, by default 1 (forwards)
        
    The most used methods and properties are:
    
        > I = eR.readSpecificImage(time_point): To load image number 
        "time_point"
    
        > t = eR.timePoints: To obtain a vector containing the list of
        existing time points, which could have gaps. eg: [1,2,3,7,9,20]
        It can be used to navigate all the images or to check if all
        expected images have been produced.
    
        > S = eR.imStack: Returns a 3D array with all the images in a
        stack
    
        > eR.ffmpeg: Calls ffmpeg to create a video with the images
        contained in the folder. Videos are in a format able to run in
        power point, pc, linux and mac without installing new codecs.
        ffmpeg should be in installed in the system and in the path.
        By default command "ffmpeg" is used, but in case of problems 
        can set a different string (full path and name of ffmpeg executable)
        at eR.ffmpeg_path.
        Hint: if lacking permissions to really install ffmpeg, 
            ``conda install ffmpeg``. -jklebes
    
    Guillermo Serrano Nájera 2019
%}
    properties
        expFolder
        ffmpeg_path
        mode
        format
        timePoints
        currentTimePoint
        currentImage
        isDone
        fileName
    end
    
    methods
        
        function eR=expReader(expFolder, timePoints, format, mode, ffmpeg_path)
            if nargin > 0
                
                if ~isempty(expFolder)
                    eR.expFolder=[expFolder filesep];
                else
                    eR.expFolder=expFolder;
                end
                
                % predefined format of files
                if ~exist('format','var') || isempty(format)
                    if  ~isempty(eR.expFolder)
                    eR.format = eR.detectFormat(expFolder);
%                   eR.format={'img_','%04d','.tif'};
                    end
                else
                    eR.format=format;
                end
                
                if ~isempty(eR.format)
                    % if time points are not defined, count the number of files
                    if ~exist('timePoints','var') || isempty(timePoints)
                        images = dir([eR.expFolder eR.format{1} '*' eR.format{3}]);
                        eR.timePoints = [];
                        for i = {images.name}
                            name = strsplit(i{1},eR.format{1});
                            name = strsplit(name{2},eR.format{3});
                            eR.timePoints = [eR.timePoints, str2double(name{1})];
                        end
                    else
                        eR.timePoints=timePoints;
                    end

                    % default mode, direct. if 'rewind' experiment is readed
                    % backwards
                    if ~exist('mode','var') || isempty(mode)
                        eR.mode=1;
                    else
                        eR.mode=mode;
                    end

                    if eR.mode==1
                        eR.currentTimePoint=eR.timePoints(1);
                    elseif eR.mode==-1
                            eR.currentTimePoint=eR.timePoints(end);
                    else
                        disp('mode must be defined as 1 for "direct" or -1 for "rewind"');
                        return
                    end
                    disp(eR)
                    
                    try
                        eR.currentImage=readImage(eR);
                    catch error
                       disp(error)
                    end
                    
                    if ~exist('ffmpeg_path','var') || isempty(ffmpeg_path)
                        eR.ffmpeg_path = 'ffmpeg';
                    else
                        eR.ffmpeg_path = ffmpeg_path;
                    end

                    eR.isDone=false;
                end
            end
        end
        
        function format = detectFormat(eR,expFolder)
            files = dir(expFolder);
            if isempty(files)
                disp(['Attempted to start an expReader, but no files found in ' expFolder])
            end
            files = {files.name};
            files = {files{cellfun(@(x) length(x)>2, files)}};
            if isempty(files)
                format = [];
            else
                mainLength = cellfun(@(x) length(x),files);
                [repet,categ]=hist(mainLength,unique(mainLength));
                [~, maxRep] = max(repet);
                len = categ(maxRep);
                mainLength = mainLength == len;
                files = files(mainLength);

    %             imageFiles = ~cellfun('isempty',strfind(files,'.tif'));

                constant = ones(size(files{1}));
                keep_inds = zeros(1, length(files));
                min_sim = len-len/2;
                for f = 2:length(files)
                    comp = (files{f-1}==files{f});
                    if sum(comp)>min_sim
                        constant = constant.*comp;
                        keep_inds(f-1) = 1;
                        keep_inds(f) = 1;
                    end
                    
                    if f == length(files)
                        comp = (files{f-2}==files{f-1});
                        if sum(comp)>min_sim
                            constant = constant.*comp;
                            keep_inds(f-1) = 1;
                        end
                    end
                end
                numlength = sum(~constant); % number of zeros
                files = files(logical(keep_inds));
                format{1} = files{1}(1:find(~constant,1,'first')-1);
                format{2} = ['%' num2str(numlength,'%02d') 'd'];
                format{3} = files{1}(find(~constant,1,'last')+1:length(constant));
            end            
        end
        
        function I=readImage(eR)
            eR.fileName = [eR.expFolder eR.format{1} num2str(eR.currentTimePoint,eR.format{2}) eR.format{3}]; 
            I=imread(eR.fileName);
        end
        
        function [I, map]=readSpecificImage(eR, timePoint)
            eR.fileName = [eR.expFolder eR.format{1} num2str(timePoint,eR.format{2}) eR.format{3}];
            [I, map]=imread(eR.fileName);
        end
        
        function eR=step(eR)
            if eR.mode == 1
                if eR.currentTimePoint<eR.timePoints(end)
                    eR.currentTimePoint=eR.currentTimePoint+1;
                    eR.currentImage=readImage(eR);
                    if eR.currentTimePoint==eR.timePoints(end)
                        eR.isDone=true;
                    end
                end
                
            elseif eR.mode == -1
                if eR.currentTimePoint>eR.timePoints(1)
                    eR.currentTimePoint=eR.currentTimePoint-1;
                    eR.currentImage=readImage(eR);
                    if eR.currentTimePoint==eR.timePoints(1)
                        eR.isDone=true;
                    end
                end 
            end
        end
        
        function eR=backStep(eR)
            if eR.currentTimePoint>eR.timePoints(1)
                eR.currentTimePoint=eR.currentTimePoint-1;
                eR.currentImage=readImage(eR);
                if eR.currentTimePoint==eR.timePoints(1)
                    eR.isDone=true;
                end
            end 
        end
        
        function eR=jump(eR, timePoint)
            eR.currentTimePoint=timePoint;
            eR.currentImage=readImage(eR);
        end
        
        function imStack=stack(eR, timePoints)
            
            if ~exist('timePoints','var') || isempty(timePoints)
                timePoints = eR.timePoints;
            end
            
            imStack = zeros(size(eR.currentImage,1), size(eR.currentImage,2), length(timePoints));
            c = 1;
            for t = timePoints
                imStack(:,:,c) = eR.readSpecificImage(t);
                c = c+1;
            end
        end
              
        function eR = ffmpeg(eR, outPath, videoName, args)
            if ~exist('args','var') || isempty(args)
                args = {[
                    ' -y -r 10 -start_number ' num2str(eR.timePoints(1)) ' -i '],...
                    ' -vcodec msmpeg4 -vf scale=1920:-1 -q:v 8 ',...
                    };
%                 
%                 args = {[
%                     ' -y -r 10 -start_number ' num2str(eR.timePoints(1)) ' -i '],...
%                     ' -c:v libx265 -pix_fmt yuv420p -vf scale=1920:-1 -q:v 8 ',...
%                     };
                
                %% Try something like this if you cannot play the video in windows media player/power point ...
%                 args = {[' -y -r 2 -start_number ' num2str(eR.timePoints(1)) ' -i '],...
%     '  -codec:v mpeg4 -flags:v +qscale -global_quality:v 0 -codec:a libmp3lame '};
            end
            
            if ~exist('outPath','var') || isempty(outPath)
                outPath = eR.expFolder;
            end
            
            if ~exist('videoName','var') || isempty(videoName)
                n = strsplit(eR.expFolder,filesep);
                n = n(cellfun(@(x) length(x),n)>0);
                videoName = {n{end},'.avi'};
%                 videoName = {n{end},'.mp4'};
            end
            
            command = [eR.ffmpeg_path args{1} eR.expFolder filesep strjoin(eR.format,'')...
                    args{2} outPath filesep videoName{1} videoName{2}];
            
            disp(command)
            system(command);
            
            %transform video to be played in web and cell phones
%             system('ffmpeg -i 0001_focusing.avi -vcodec libx264 -vprofile high -preset slow -b:v 500k -maxrate 500k -bufsize 1000k -vf scale=-1:480 -threads 0 -acodec libvo_aacenc -b:a 128k output_file.mp4')
        end
        
        function insertTextSeq(eR,options)
            if ~exist('options','var') || isempty(options);
                options={'FontSize',70,'TextColor','white','BoxColor','Black','BoxOpacity',1};
            end
            
            for idx=eR.timePoints;
                disp(num2str(idx));
                eR.jump(idx);
                I = insertText(eR.currentImage,[1,1],['image: ' num2str(idx,eR.format{2})],options{:});
                imwrite(I,eR.fileName);
            end
        end
        
        function reNumberSeq(eR, outFolder, seqFormat)
            
            eR.jump(eR.timePoints(1));
            mkdir(outFolder)
            counter = seqFormat{1};
            for tIdx = eR.timePoints;
                imwrite(eR.currentImage,[outFolder filesep eR.format{1} num2str(counter, eR.format{2}) eR.format{3}]);
                eR.jump(tIdx);
                counter = counter + seqFormat{2};
            end
        end
        
        function convertPaths(eR)
            eR.expFolder = pathConverter(eR.expFolder);
        end
    end
    
end