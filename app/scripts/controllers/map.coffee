'use strict'

tripPlannerApp.controller 'MapCtrl', ($scope, $timeout, $q, $dialog, Geocoder, Directions) ->

  $scope.Math = window.Math

  $scope.alerts = []
  $scope.markers = []
  $scope.legs = []
  $scope.locationText = value: ''

  $scope.tripInfo = {
    duration: null,
    distance: null
  }

  $scope.mapOptions = {
    center: new google.maps.LatLng(50, 0),
    zoom: 9,
    mapTypeId: google.maps.MapTypeId.ROADMAP
  }

  $scope.directionsModes = Directions.directionsModes
  $scope.directionsMode = value: $scope.directionsModes['Driving']

  directionsDisplay = new google.maps.DirectionsRenderer({
    preserveViewport: true
  })

  $scope.$watch 'directionsMode.value', (directionsMode) ->
    $scope.updateDirections directionsMode

  $scope.$watch 'map', (map) ->
    directionsDisplay.setMap map

  # Update the directions display
  $scope.updateDirections = ->
    if $scope.markers.length < 2
      directionsDisplay.setMap null
      marker.setVisible true for marker in $scope.markers
    else
      $timeout ->
        promise = Directions.getDirections $scope.markers, {
          travelMode: $scope.directionsMode.value
        }

        promise.then (result) ->
          $scope.legs = result.routes[0].legs

          # Re-calculate the trip time and distance
          $scope.tripInfo.distance = 0
          $scope.tripInfo.duration = 0

          $scope.tripInfo.distance += leg.distance.value for leg in $scope.legs
          $scope.tripInfo.duration += leg.duration.value for leg in $scope.legs

          directionsDisplay.setMap $scope.map

          # Hide the first & last markers so that the "A" & "B" directions markers are visible
          marker.setVisible true for marker in $scope.markers
          $scope.markers[0].setVisible false
          $scope.markers[$scope.markers.length - 1].setVisible false

          directionsDisplay.setDirections result
        , (reason) ->
          $scope.alerts.push "Unable to get directions. #{reason}"

  # Add a marker to the map, based on a click event
  $scope.addMarker = ($event) ->
    marker = new google.maps.Marker({
      map: $scope.map,
      position: $event.latLng
    })

    $scope.markers.push marker

    promise = Geocoder.getLocation marker.getPosition()

    promise.then (results) ->
      marker.location = results.shift()
    , (reason) ->
      $scope.alerts.push "Unable to reverse geocode marker. #{reason}"

    $scope.updateDirections()

  # Add a marker to the map by typing a location
  $scope.addLocation = (location) ->
    addLocationDeferred = $q.defer()
    addLocationDeferred.promise.then (location) ->
        $scope.addMarker { latLng: location.geometry.location }
        $timeout ->
          $scope.locationText.value = ''

    Geocoder.getLatLng(location).then (results) ->
      if results.length == 1
        addLocationDeferred.resolve results[0]
      else
        dialog = $dialog.dialog(resolve: {
          query: ->
            location
          locations: ->
            results
        })

        promise = dialog.open 'views/location-modal.html', 'LocationModalCtrl'
        promise.then (location) ->
          addLocationDeferred.resolve location

  # Remove marker at position #{index}
  $scope.removeMarker = (index) ->
    marker = $scope.markers.splice(index, 1)[0]
    marker.setMap null

    $scope.updateDirections()

  # Center the map based on the user's current location
  if (navigator.geolocation)
    navigator.geolocation.getCurrentPosition (position) ->
      $scope.map.panTo new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
      $scope.$apply()
    , (error) ->
      $scope.alerts.push "We weren't able to determine your current location."
      $scope.$apply()

  # Remove an alert
  $scope.closeAlert = (index) ->
    $scope.alerts.splice index, 1
