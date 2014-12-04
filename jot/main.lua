phoneType = getPhoneType()

if phoneType == "32" then
    digitsNetworkURI = getAppPath() .. "/nets/digits_32.net"
    signsNetworkURI = getAppPath() .. "/nets/signs_32.net"
elseif phoneType == "64" then
    digitsNetworkURI = getAppPath() .. "/nets/digits_64.net"
    signsNetworkURI = getAppPath() .. "/nets/signs_64.net"
end


digitsNetwork = torch.load(digitsNetworkURI)
--torch.save(getAppPath() .. "/digits_6.net", digitsNetwork)


signsNetwork = torch.load(signsNetworkURI)
--torch.save(getAppPath() .. "/signs_6.net", signsNetwork)


function classify(binaryImage, size)
    inputImage = loadImage(binaryImage, size)

    digit = prepareImage(inputImage)

    output = digitsNetwork:forward(digit)
    y, result = torch.max(output, 1)

    return result[1]-1
end



function classifySign(binaryImage, size)
    inputImage = loadImage(binaryImage, size)

    sign = prepareImage(inputImage)

    output = signsNetwork:forward(sign)
    y, result = torch.max(output, 1)

    return result[1]
end




function loadImage(binaryImage, size)
    rows = size[1]
    cols = size[2]
    numberOfPixels = table.getn(binaryImage)

    --print("number of pixels: " .. numberOfPixels .. ", rows: " .. rows .. ", cols: " .. cols)

    inputImage = torch.Tensor(1, rows, cols)
    t2 = inputImage:storage()

    for i = 1, numberOfPixels do
        t2[i] = binaryImage[i]
    end
    return inputImage
end

function prepareImage(img)
    imgSize = img:size()
    h, w = img:size(2), img:size(3)

    bigDim = 1.3 * math.max(h, w)
    --smallDim = math.min(h, w)
    tlCornerY = math.floor((bigDim - h) / 2)
    tlCornerX = math.floor((bigDim - w) / 2)

    squareDigit = torch.zeros(1, bigDim, bigDim)

    squareDigit[{1, {tlCornerY,tlCornerY+h-1}, {tlCornerX,tlCornerX+w-1}}] = img

    digit32x32 = image.scale(squareDigit, 32, 32)

    result = normalizeImage(digit32x32)

    --output = torch.Tensor(1, 1, 32, 32)

    --output[1] = result:type('torch.DoubleTensor')

    return result
end

function normalizeImage(img)
    mean = img:mean()
    std = img:std()
    img:add(-mean)
    img:div(std)

    return img
end