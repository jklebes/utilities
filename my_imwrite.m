function my_imwrite(image,filename, varargin)
% a centralized place to decide on file format
% and compression for all images - prefer jp2, CompressionRatio 10
default_file_format='jp2';
if ~isempty(varargin)
    file_format=varargin{1} ;
else
    file_format=default_file_format;
end
if strcmp(file_format, 'jp2') || strcmp(file_format, 'jpx')
    imwrite(image, filename, file_format, CompressionRatio=10);
else
    imwrite(image, filename, file_format);
end
end