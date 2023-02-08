function out_path = pathConverter(in_path, test)
%{
    Function to transform paths from pc to unix and viceversa.

    INPUT:
        > in_path. A path to a directory from windows or linux
        > test. if 1/True returns the path in the other OS:
            from windows to linux in a windows machine
            from linux to windows in a linux machine

    OUTPUT:
        > Working path in the current OS. (unless test=1, see above)

    IMPORTANT:
        This works between window machine with the appropiate mapping of the
        CJW lab servers and the t640 server.

        \\cjw-raid.lifesci.dundee.ac.uk must be mapped as X:\\ and/or Y:\\ in windows
        \\cjw-t640.lifesci.dundee.ac.uk must be mapped as A:\\ in windows
                
                                             Guillermo Serrano Nájera (2020)

%}
    if ~isempty(in_path)
        if ~exist('test','var') || isempty(test)
            test = 0;
        end

        if contains(in_path, '\')
            pc_path = true;
        else
            pc_path = false;
        end

        if (ispc && ~pc_path) || (~pc_path && test)

            if startsWith(in_path, '/mnt/RemoteStorage')
                out_path = strrep(in_path, '/mnt/RemoteStorage/mDrives/raid0/expk/', 'Z:\DSLM_expk\');
%                 out_path = strrep(in_path, '/mnt/RemoteStorage/mDrives/raid0/', 'Z:\DSLM_expk\');
            elseif startsWith(in_path, '/mnt/LocalStorage/md3400-big')
                out_path = strrep(in_path, '/mnt/LocalStorage/md3400-big', 'A:');
            else
                out_path = in_path;
            end

            out_path = strrep(out_path, '/', '\');

        elseif (isunix && pc_path) || (pc_path && test)

            out_path = strrep(in_path, '\', '/');
            out_path = strrep(out_path, ':', '');
            if ismember(out_path(1), ['Y', 'X', 'Z'])
                out_path = ['/mnt/RemoteStorage' out_path(2:end)];
            elseif ismember(out_path(1), ['A'])
                out_path = ['/mnt/LocalStorage/md3400-big' out_path(2:end)];        
            end

            % windows finds the path with even with lowercase, but linux cannnot 
            out_path = strrep(out_path, 'raid0_', 'Raid0_'); % I had a problem with this so many times...
        else
            out_path = in_path;
        end
    else
        out_path = in_path;
    end
    
end